import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/day_entry.dart';
import '../models/task.dart';

final _uuid = Uuid();

/// The file format shown in the live JSON panel. Keys are deliberately small
/// and stable: `id` keeps a row's identity, `days` is the schedule, and the
/// rest are the task's own fields. Unknown keys are ignored on the way in so
/// adding notes to the JSON does not break the importer.
String encodeTasksJson(List<Task> tasks, List<DayEntry> entries) {
  final byTask = <String, List<String>>{};
  for (final e in entries) {
    byTask.putIfAbsent(e.taskId, () => []).add(e.dateKey);
  }
  return _encodeRows(tasks, byTask);
}

/// Same format, but from the parsed shape. Used when merging two JSON files:
/// there are no [DayEntry] objects yet, only the schedule map from the parser.
String encodeTasksWithDays(List<Task> tasks, Map<String, List<DateTime>> days) => _encodeRows(
      tasks,
      days.map((k, v) => MapEntry(k, v.map(DayEntry.dateToKey).toList())),
    );

String _encodeRows(List<Task> tasks, Map<String, List<String>> byTask) {
  final rows = <Map<String, dynamic>>[];
  for (final t in tasks) {
    final days = (byTask[t.id] ?? <String>[])..sort();
    final row = <String, dynamic>{'id': t.id, 'name': t.name, 'position': t.position};
    if (t.reminder != null && t.reminder!.isNotEmpty) row['reminder'] = t.reminder;
    row['tags'] = t.tags;
    row['days'] = days;
    rows.add(row);
  }
  return const JsonEncoder.withIndent('  ').convert(rows);
}

/// Parse [text] into tasks plus an optional schedule map.
///
/// Only ids present in [days] get their schedule replaced; a task whose JSON
/// object leaves out `days` keeps the days it already had. `needsIds` reports
/// that a row had no id, so the caller can write the generated ids back into
/// the editor — otherwise the next edit would create a different task.
({List<Task> tasks, Map<String, List<DateTime>> days, bool needsIds}) parseTasksJson(
  String text, {
  required String userId,
  required Task? Function(String id) byId,
}) {
  final decoded = jsonDecode(text);
  if (decoded is! List) throw const FormatException('Top level must be an array of tasks.');
  final now = DateTime.now();
  final tasks = <Task>[];
  final days = <String, List<DateTime>>{};
  final ids = <String>{};
  var needsIds = false;

  for (var i = 0; i < decoded.length; i++) {
    final raw = decoded[i];
    final n = i + 1;
    if (raw is! Map) throw FormatException('Task $n must be an object.');
    final m = Map<String, dynamic>.from(raw);

    final name = m['name'];
    if (name is! String || name.trim().isEmpty) throw FormatException('Task $n needs a non-empty "name".');

    String id;
    final rawId = m['id'];
    if (rawId is String && rawId.trim().isNotEmpty) {
      id = rawId.trim();
      if (!ids.add(id)) throw FormatException('Duplicate id "$id" on task $n.');
    } else {
      id = _uuid.v4();
      ids.add(id);
      needsIds = true;
    }

    final rem = m['reminder'];
    if (rem != null && rem is! String) throw FormatException('Task $n: "reminder" must be a string or null.');
    final reminder = rem is String && rem.trim().isEmpty ? null : rem as String?;

    final tagsRaw = m['tags'] ?? const <dynamic>[];
    if (tagsRaw is! List) throw FormatException('Task $n: "tags" must be an array.');
    final tags = <String>[];
    for (final tag in tagsRaw) {
      if (tag is! String) throw FormatException('Task $n: tag ids must be strings.');
      tags.add(tag);
    }

    final posRaw = m['position'];
    final position = posRaw is num ? posRaw.toInt() : i;

    final old = byId(id);
    tasks.add(Task(
      id: id,
      name: name.trim(),
      position: position,
      createdAt: old?.createdAt ?? now,
      userId: old?.userId ?? userId,
      reminder: reminder,
      tags: tags,
    ));

    // Absent "days" = leave the schedule alone. Present, even as [], means
    // make the schedule exactly this.
    if (m.containsKey('days')) {
      final daysRaw = m['days'];
      if (daysRaw is! List) throw FormatException('Task $n: "days" must be an array of YYYY-MM-DD dates.');
      final parsed = <DateTime>[];
      for (final d in daysRaw) {
        if (d is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d.trim())) {
          throw FormatException('Task $n: bad day "$d" — use YYYY-MM-DD.');
        }
        final dt = DateTime.parse(d.trim());
        parsed.add(DateTime(dt.year, dt.month, dt.day));
      }
      days[id] = parsed;
    }
  }
  return (tasks: tasks, days: days, needsIds: needsIds);
}

/// Append the rows in [importedText] to [baseText].
///
/// A row whose id already exists in the base is skipped rather than added
/// twice: ids are the identity that day cells and tag dots hang off. To force
/// a copy, the incoming row should simply leave its `id` out. Positions are
/// reassigned so new rows land after the existing ones.
({String json, int added, int skipped}) mergeTaskJson(
  String baseText,
  String importedText, {
  required String userId,
  required Task? Function(String id) byId,
}) {
  final base = parseTasksJson(baseText, userId: userId, byId: byId);
  final imported = parseTasksJson(importedText, userId: userId, byId: byId);
  final ids = base.tasks.map((t) => t.id).toSet();
  final addedTasks = <Task>[];
  var skipped = 0;
  for (final task in imported.tasks) {
    if (!ids.add(task.id)) {
      skipped++;
      continue;
    }
    addedTasks.add(task);
  }
  final days = <String, List<DateTime>>{...base.days};
  for (final task in addedTasks) {
    final d = imported.days[task.id];
    if (d != null) days[task.id] = d;
  }
  final combined = <Task>[...base.tasks];
  for (final task in addedTasks) {
    combined.add(task.copyWith(position: combined.length));
  }
  return (json: encodeTasksWithDays(combined, days), added: addedTasks.length, skipped: skipped);
}
