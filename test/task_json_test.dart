import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_sheet/models/day_entry.dart';
import 'package:tracker_sheet/models/task.dart';
import 'package:tracker_sheet/utils/task_json.dart';

Task _task(String id, String name, {List<String> tags = const [], String? reminder, int position = 0}) => Task(
      id: id,
      name: name,
      position: position,
      createdAt: DateTime(2026, 1, 2),
      userId: 'u',
      reminder: reminder,
      tags: tags,
    );

DayEntry _entry(String taskId, DateTime date) => DayEntry(
      id: 'e-${taskId}-${date.day}',
      taskId: taskId,
      userId: 'u',
      date: date,
      checked: true,
      data: const {},
    );

void main() {
  test('round-trips names, tags, reminders and sorted days', () {
    final task = _task('a', 'Gym', tags: ['red', 'work'], reminder: '10MI');
    final entries = [
      _entry('a', DateTime(2026, 11, 18)),
      _entry('a', DateTime(2026, 11, 16)),
    ];
    final json = encodeTasksJson([task], entries);
    final rows = jsonDecode(json) as List;
    expect(rows.first['name'], 'Gym');
    expect(rows.first['tags'], ['red', 'work']);
    expect(rows.first['reminder'], '10MI');
    expect(rows.first['days'], ['2026-11-16', '2026-11-18']);

    final parsed = parseTasksJson(json, userId: 'u', byId: (id) => id == 'a' ? task : null);
    expect(parsed.tasks.single.name, 'Gym');
    // Existing tasks keep their server identity, not a fresh timestamp/user.
    expect(parsed.tasks.single.createdAt, task.createdAt);
    expect(parsed.tasks.single.userId, 'u');
    expect(parsed.days['a']!.map((d) => d.day).toList(), [16, 18]);
    expect(parsed.needsIds, isFalse);
  });

  test('a row without id gets generated once, and missing days keeps the schedule', () {
    final parsed = parseTasksJson(
      '[{"name":"New task"}]',
      userId: 'u',
      byId: (_) => null,
    );
    expect(parsed.tasks.single.name, 'New task');
    expect(parsed.tasks.single.id, isNotEmpty);
    expect(parsed.tasks.single.userId, 'u');
    expect(parsed.needsIds, isTrue);
    // No "days" key: the caller must not touch this task's schedule.
    expect(parsed.days, isEmpty);
  });

  test('an empty days array is a deliberate instruction to clear the schedule', () {
    final parsed = parseTasksJson(
      '[{"id":"a","name":"Gym","days":[]}]',
      userId: 'u',
      byId: (id) => _task(id, 'Gym'),
    );
    expect(parsed.days.containsKey('a'), isTrue);
    expect(parsed.days['a'], isEmpty);
  });

  test('merge appends new rows and skips ids already in the table', () {
    final base = encodeTasksJson([_task('a', 'Existing')], const []);
    const file = '[{"id":"a","name":"Edited elsewhere"},{"id":"b","name":"Brand new","days":["2026-11-20"]}]';
    final merged = mergeTaskJson(
      base,
      file,
      userId: 'u',
      byId: (id) => id == 'a' ? _task(id, 'Existing') : null,
    );
    expect(merged.added, 1);
    expect(merged.skipped, 1);
    final rows = jsonDecode(merged.json) as List;
    expect(rows.length, 2);
    expect(rows.first['name'], 'Existing');
    expect(rows.last['name'], 'Brand new');
    expect(rows.last['days'], ['2026-11-20']);
    expect(rows.last['position'], 1);
  });

  test('merge keeps the existing schedule and gives id-less rows a fresh id', () {
    final base = encodeTasksJson([_task('a', 'Existing')], [_entry('a', DateTime(2026, 11, 16))]);
    const file = '[{"name":"From file"}]';
    final merged = mergeTaskJson(base, file, userId: 'u', byId: (_) => null);
    expect(merged.added, 1);
    expect(merged.skipped, 0);
    final rows = jsonDecode(merged.json) as List;
    expect(rows.first['days'], ['2026-11-16']);
    expect(rows.last['name'], 'From file');
    expect(rows.last['id'], isNotEmpty);
  });

  test('malformed JSON is rejected before anything can be applied', () {
    expect(() => parseTasksJson('{}', userId: 'u', byId: (_) => null), throwsFormatException);
    expect(() => parseTasksJson('[{"name":""}]', userId: 'u', byId: (_) => null), throwsFormatException);
    expect(() => parseTasksJson('[{"name":"a","days":["16/11/2026"]}]', userId: 'u', byId: (_) => null), throwsFormatException);
    expect(() => parseTasksJson('[{"name":"a","id":"x","tags":"red"}]', userId: 'u', byId: (_) => null), throwsFormatException);
    expect(() => parseTasksJson('[{"name":"a","id":"x"},{"name":"b","id":"x"}]', userId: 'u', byId: (_) => null), throwsFormatException);
  });
}
