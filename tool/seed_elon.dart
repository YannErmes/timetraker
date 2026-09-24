/// Seeds a busy demo workspace for elonmusk@gmail.com (September 2026).
/// Run with SUPABASE_URL + SUPABASE_ANON_KEY in the environment:
///   $env:SUPABASE_URL="..."; $env:SUPABASE_ANON_KEY="..."; dart run tool/seed_elon.dart
/// Idempotent: wipes that user's tasks/columns/entries first (fresh demo).
import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

final _url = Platform.environment['SUPABASE_URL'] ?? '';
final _key = Platform.environment['SUPABASE_ANON_KEY'] ?? '';
const _email = 'elonmusk@gmail.com';
const _uuid = Uuid();

Future<void> main() async {
  if (_url.isEmpty || _key.isEmpty) {
    print('Missing SUPABASE_URL / SUPABASE_ANON_KEY env vars');
    return;
  }
  final db = SupabaseClient(_url, _key);

  // 1. Identity (app looks users up by exact email).
  final existing = await db.from('app_users').select().eq('name', _email).maybeSingle();
  final userId = (existing?['id'] as String?) ?? _uuid.v4();
  if (existing == null) {
    await db.from('app_users').insert({'id': userId, 'name': _email});
    print('created user $_email ($userId)');
  } else {
    print('user exists $_email ($userId)');
  }

  // 2. Fresh slate for the demo (day_entries cascade via task FK).
  await db.from('tasks').delete().eq('user_id', userId);
  await db.from('column_definitions').delete().eq('user_id', userId);
  print('cleared old demo data');

  // 3. Columns (app defaults).
  const statusOpts = [
    {'id': 'none', 'label': 'none', 'colorHex': '#475569'},
    {'id': 'done', 'label': 'done', 'colorHex': '#22C55E'},
    {'id': 'cancel', 'label': 'cancel', 'colorHex': '#F43F5E'},
    {'id': 'in_progress', 'label': 'in progress', 'colorHex': '#F59E0B'},
  ];
  await db.from('column_definitions').insert([
    {'id': 'col_schedule', 'user_id': userId, 'label': 'schedule', 'type': 'schedule', 'position': 0, 'config': {}},
    {'id': 'col_time', 'user_id': userId, 'label': 'time', 'type': 'timer', 'position': 1, 'config': {}},
    {'id': 'col_status', 'user_id': userId, 'label': 'status', 'type': 'status', 'position': 2, 'config': {'options': statusOpts}},
    {'id': 'col_note', 'user_id': userId, 'label': 'note', 'type': 'text', 'position': 3, 'config': {}},
  ]);
  print('inserted 4 columns');

  // 4. Seven busy-guy tasks.
  const taskNames = [
    'Starship Flight Review',
    'Optimus Production',
    'Grok Training Run',
    'Neuralink Trial',
    'X Algorithm Tuning',
    'Robotaxi Rollout',
    'Investor Calls',
  ];
  final taskIds = <String>[];
  for (int i = 0; i < taskNames.length; i++) {
    final id = _uuid.v4();
    taskIds.add(id);
    await db.from('tasks').insert({'id': id, 'user_id': userId, 'name': taskNames[i], 'position': i});
  }
  print('inserted ${taskNames.length} tasks');

  // 5. A packed September 2026. Past days read done/in_progress,
  //    today is hot, future is planned.
  const notes = [
    'Review Raptor 3 test data with propulsion team',
    'Walk the line — check actuator tolerances',
    'Loss curves finally bending, scale to full cluster',
    'Patient 9 implant went clean, monitor signal quality',
    'For-you weights feel off, rebalance recency vs quality',
    'Austin corridor expansion approved, permits next',
    'Q3 numbers call at 4pm, keep it tight',
    'Heat-shield tile gaps on ship 33 need a second look',
    'Hands are still too slow on box stacking, retrain demo',
    'Eval harness green across the board, ship the checkpoint',
    'First closed-loop typing session, huge milestone',
    'Ads pacing recovered after the ranking push',
    'Safety driver fallback review with legal',
    'Starlink revenue deck for the board',
  ];
  const times = ['07:30', '08:00', '09:00', '10:30', '13:00', '15:00', '16:30', '18:00'];
  const durations = [3600, 5400, 7200, 10800, 14400];

  final rows = <Map<String, dynamic>>[];
  int noteIdx = 0;
  for (int day = 1; day <= 30; day++) {
    final date = DateTime(2026, 9, day);
    final weekday = date.weekday; // 1 Mon .. 7 Sun
    final isWeekend = weekday >= 6;
    for (int t = 0; t < taskNames.length; t++) {
      // Busy pattern: weekdays 4-6 tasks, weekends 1-2.
      final slot = (day + t * 3) % 7;
      final scheduled = isWeekend ? (slot < 2) : (slot < 5);
      if (!scheduled) continue;
      String status;
      if (day < 24) {
        status = (day + t) % 9 == 0 ? 'cancel' : ((day + t) % 3 == 0 ? 'in_progress' : 'done');
      } else if (day == 24) {
        status = t % 3 == 0 ? 'in_progress' : (t % 3 == 1 ? 'none' : 'done');
      } else {
        status = (day + t) % 5 == 0 ? 'in_progress' : 'none';
      }
      final withNote = (day * 7 + t) % 3 != 0;
      final data = <String, dynamic>{
        'col_schedule': times[(day + t) % times.length],
        'col_time': {
          'durationSec': durations[(day + t) % durations.length],
          'elapsedSec': 0,
          'running': status == 'in_progress' && day == 24,
          'startedAtIso': null,
        },
        'col_status': status,
      };
      if (withNote) {
        data['col_note'] = notes[noteIdx % notes.length];
        noteIdx++;
      }
      rows.add({
        'id': _uuid.v4(),
        'user_id': userId,
        'task_id': taskIds[t],
        'entry_date': '2026-09-${day.toString().padLeft(2, '0')}',
        'checked': true,
        'data': data,
      });
    }
  }
  // Batch insert in chunks.
  for (int i = 0; i < rows.length; i += 50) {
    await db.from('day_entries').insert(rows.skip(i).take(50).toList());
  }
  print('inserted ${rows.length} day entries across September 2026');
  print('JSON check: ${jsonEncode(rows.length)} rows');
  print('DONE — sign in as $_email on any device to demo the busy calendar.');
}
