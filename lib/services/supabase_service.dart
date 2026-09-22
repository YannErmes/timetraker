import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/supabase_config.dart';
import '../models/task.dart';
import '../models/column_definition.dart';
import '../models/day_entry.dart';
import '../models/enums.dart';
import '../models/timer_value.dart';
import 'sync_service.dart';

const _uuid = Uuid();

class SupabaseService {
  final OfflineCache _cache = OfflineCache();
  SupabaseClient? get _client => isSupabaseConfigured ? Supabase.instance.client : null;
  bool get isConfigured => isSupabaseConfigured;
  bool get isLoggedIn => isConfigured ? _client!.auth.currentUser != null : _demoLoggedIn;
  String? get userId => isConfigured ? _client!.auth.currentUser?.id : _demoUserId;

  // Demo mode (no supabase configured) - in-memory
  bool _demoLoggedIn = false;
  String _demoUserId = 'demo-user';
  final List<Task> _demoTasks = [];
  final List<ColumnDefinition> _demoCols = [];
  final List<DayEntry> _demoEntries = [];
  bool _demoInit = false;

  final _tasksCtrl = StreamController<List<Task>>.broadcast();
  final _colsCtrl = StreamController<List<ColumnDefinition>>.broadcast();
  final _entriesCtrl = StreamController<List<DayEntry>>.broadcast();

  Stream<List<Task>> get tasksStream => _tasksCtrl.stream;
  Stream<List<ColumnDefinition>> get columnsStream => _colsCtrl.stream;
  Stream<List<DayEntry>> get entriesStream => _entriesCtrl.stream;

  List<Task> _tasks = [];
  List<ColumnDefinition> _columns = [];
  List<DayEntry> _entries = [];

  List<Task> get tasks => _tasks;
  List<ColumnDefinition> get columns => _columns;
  List<DayEntry> get entries => _entries;

  RealtimeChannel? _tasksCh;
  RealtimeChannel? _colsCh;
  RealtimeChannel? _entriesCh;
  StreamSubscription? _connSub;

  Future<void> init() async {
    if (!isConfigured) {
      await _initDemo();
      _startStatusTicker();
      return;
    }
    await _loadFromCache();
    await _fetchAll();
    _subscribeRealtime();
    _startStatusTicker();
    _connSub = Connectivity().onConnectivityChanged.listen((_) => _flushQueue());
    _client!.auth.onAuthStateChange.listen((event) async {
      if (event.event == AuthChangeEvent.signedIn) {
        await _fetchAll();
        _subscribeRealtime();
        _startStatusTicker();
      } else if (event.event == AuthChangeEvent.signedOut) {
        _unsubscribe();
        _statusTicker?.cancel();
      }
    });
  }

  Future<void> _loadFromCache() async {
    try {
      final tRows = await _cache.loadTasks();
      final cRows = await _cache.loadColumns();
      final eRows = await _cache.loadEntries();
      if (tRows.isNotEmpty) {
        _tasks = tRows.map((j) => Task.fromSupabase(j)).toList()..sort((a, b) => a.position.compareTo(b.position));
        _tasksCtrl.add(_tasks);
      }
      if (cRows.isNotEmpty) {
        _columns = cRows.map((j) => ColumnDefinition.fromSupabase(j)).toList()..sort((a, b) => a.position.compareTo(b.position));
        _colsCtrl.add(_columns);
      }
      if (eRows.isNotEmpty) {
        _entries = eRows.map((j) => DayEntry.fromSupabase(j)).toList();
        _ensureDefaultStatusForAll();
        _entriesCtrl.add(_entries);
      }
    } catch (e) {
      debugPrint('cache load err $e');
    }
  }

  void _ensureDefaultStatusForAll() {
    final statusCol = _columns.where((c) => c.type == ColumnType.status).firstOrNull;
    if (statusCol == null) return;
    bool changed = false;
    for (int i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (e.checked && !e.data.containsKey(statusCol.id)) {
        final updated = e.withValue(statusCol.id, 'none');
        _entries[i] = updated;
        changed = true;
      }
    }
    if (changed) {
      _persistCache();
      // also push to remote if configured (best-effort, no need to await)
      if (isConfigured) {
        for (final e in _entries) {
          if (e.checked) {
            final statusCol2 = _columns.where((c) => c.type == ColumnType.status).firstOrNull;
            if (statusCol2 != null && !e.data.containsKey(statusCol2.id)) {
              // already handled
            }
          }
        }
      }
    }
  }

  Future<void> _persistCache() async {
    await _cache.saveTasks(_tasks.map((t) => {'id': t.id, 'name': t.name, 'position': t.position, 'created_at': t.createdAt.toIso8601String(), 'user_id': t.userId}).toList());
    await _cache.saveColumns(_columns.map((c) => c.toSupabase(userId!)).toList());
    await _cache.saveEntries(_entries.map((e) => e.toSupabase()).toList());
  }

  void _subscribeRealtime() {
    if (!isConfigured || userId == null) return;
    _unsubscribe();
    final uid = userId!;
    _tasksCh = _client!.channel('tasks-$uid')
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'tasks', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid), callback: (_) => _fetchTasks())
      ..subscribe();
    _colsCh = _client!.channel('cols-$uid')
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'column_definitions', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid), callback: (_) => _fetchColumns())
      ..subscribe();
    _entriesCh = _client!.channel('entries-$uid')
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'day_entries', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid), callback: (_) => _fetchEntries())
      ..subscribe();
  }

  void _unsubscribe() {
    if (_tasksCh != null) _client!.removeChannel(_tasksCh!);
    if (_colsCh != null) _client!.removeChannel(_colsCh!);
    if (_entriesCh != null) _client!.removeChannel(_entriesCh!);
  }

  Future<void> _fetchAll() async {
    await _fetchTasks();
    await _fetchColumns();
    await _fetchEntries();
    // ensure scheduled entries have default status 'none' after both are loaded
    _ensureDefaultStatusForAll();
    _entriesCtrl.add(_entries);
    await _persistCache();
  }

  Future<void> _fetchTasks() async {
    if (!isConfigured || userId == null) return;
    final res = await _client!.from('tasks').select().eq('user_id', userId!).order('position');
    _tasks = (res as List).map((j) => Task.fromSupabase(Map<String, dynamic>.from(j))).toList();
    _tasksCtrl.add(_tasks);
    await _persistCache();
  }

  Future<void> _fetchColumns() async {
    if (!isConfigured || userId == null) return;
    final res = await _client!.from('column_definitions').select().eq('user_id', userId!).order('position');
    _columns = (res as List).map((j) => ColumnDefinition.fromSupabase(Map<String, dynamic>.from(j))).toList();
    // seed defaults if empty
    if (_columns.isEmpty) {
      final defaults = ColumnDefinition.defaultColumns();
      for (final c in defaults) {
        await _client!.from('column_definitions').insert(c.toSupabase(userId!));
      }
      final r2 = await _client!.from('column_definitions').select().eq('user_id', userId!).order('position');
      _columns = (r2 as List).map((j) => ColumnDefinition.fromSupabase(Map<String, dynamic>.from(j))).toList();
    } else {
      // Migration: ensure Schedule column exists at position 0 and Time is timer, and Note exists
      bool needsRefetch = false;
      final hasSchedule = _columns.any((c) => c.id == 'col_schedule');
      if (!hasSchedule) {
        final schedule = ColumnDefinition.defaultColumns().firstWhere((c) => c.id == 'col_schedule');
        for (final c in _columns) {
          await _client!.from('column_definitions').update({'position': c.position + 1}).eq('id', c.id);
        }
        await _client!.from('column_definitions').insert(schedule.toSupabase(userId!));
        needsRefetch = true;
      }
      final hasNote = _columns.any((c) => c.id == 'col_note');
      if (!hasNote) {
        final note = ColumnDefinition.defaultColumns().firstWhere((c) => c.id == 'col_note');
        // append at end
        await _client!.from('column_definitions').insert(note.copyWith(position: _columns.length + (hasSchedule ? 0 : 1)).toSupabase(userId!));
        needsRefetch = true;
      }
      final timeCol = _columns.where((c) => c.id == 'col_time').firstOrNull;
      if (timeCol != null && timeCol.type != ColumnType.timer) {
        await _client!.from('column_definitions').update({'type': ColumnType.timer.name, 'config': {}}).eq('id', 'col_time');
        try {
          final entriesRes = await _client!.from('day_entries').select().eq('user_id', userId!);
          for (final row in (entriesRes as List)) {
            final data = row['data'] is Map ? Map<String, dynamic>.from(row['data']) : <String, dynamic>{};
            if (data.containsKey('col_time') && data['col_time'] is String) {
              final sec = _parseDurationToSec(data['col_time'] as String);
              if (sec > 0) {
                data['col_time'] = {'durationSec': sec, 'elapsedSec': 0, 'running': false, 'startedAtIso': null};
                await _client!.from('day_entries').update({'data': data}).eq('id', row['id']);
              }
            }
          }
        } catch (_) {}
        needsRefetch = true;
      }
      if (needsRefetch) {
        final r2 = await _client!.from('column_definitions').select().eq('user_id', userId!).order('position');
        _columns = (r2 as List).map((j) => ColumnDefinition.fromSupabase(Map<String, dynamic>.from(j))).toList();
      }
    }
    // ensure order by position is canonical 0..n-1 for display (Schedule -> Time -> Status)
    _columns.sort((a, b) => a.position.compareTo(b.position));
    _colsCtrl.add(_columns);
    await _persistCache();
  }

  Future<void> _fetchEntries() async {
    if (!isConfigured || userId == null) return;
    final res = await _client!.from('day_entries').select().eq('user_id', userId!);
    _entries = (res as List).map((j) => DayEntry.fromSupabase(Map<String, dynamic>.from(j))).toList();
    _ensureDefaultStatusForAll();
    _entriesCtrl.add(_entries);
    await _persistCache();
  }

  // Auth - email/password only
  Future<void> signUp(String email, String password) async {
    if (!isConfigured) {
      _demoLoggedIn = true;
      await _initDemo();
      return;
    }
    await _client!.auth.signUp(email: email, password: password);
  }

  Future<void> signIn(String email, String password) async {
    if (!isConfigured) {
      _demoLoggedIn = true;
      await _initDemo();
      return;
    }
    await _client!.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    if (!isConfigured) {
      _demoLoggedIn = false;
      return;
    }
    await _client!.auth.signOut();
  }

  // Tasks CRUD
  Future<void> addTask(String name) async {
    final t = Task(id: _uuid.v4(), name: name, position: _tasks.length, createdAt: DateTime.now(), userId: userId!);
    // optimistic
    _tasks = [..._tasks, t];
    _tasksCtrl.add(_tasks);
    await _persistCache();
    if (!isConfigured) {
      _demoTasks.add(t);
      return;
    }
    try {
      await _client!.from('tasks').insert({'id': t.id, 'name': t.name, 'position': t.position, 'user_id': t.userId});
    } catch (e) {
      await _cache.enqueue(PendingMutation(id: _uuid.v4(), table: 'tasks', op: 'insert', payload: {'id': t.id, 'name': t.name, 'position': t.position, 'user_id': t.userId}, createdAt: DateTime.now()));
    }
  }

  Future<void> updateTask(Task t) async {
    _tasks = _tasks.map((e) => e.id == t.id ? t : e).toList();
    _tasksCtrl.add(_tasks);
    await _persistCache();
    if (!isConfigured) return;
    try {
      await _client!.from('tasks').update({'name': t.name, 'position': t.position}).eq('id', t.id);
    } catch (e) {
      await _cache.enqueue(PendingMutation(id: _uuid.v4(), table: 'tasks', op: 'update', payload: {'id': t.id, 'name': t.name, 'position': t.position}, createdAt: DateTime.now()));
    }
  }

  Future<void> deleteTask(String id) async {
    _tasks = _tasks.where((e) => e.id != id).toList();
    _tasksCtrl.add(_tasks);
    await _persistCache();
    if (!isConfigured) {
      _demoTasks.removeWhere((e) => e.id == id);
      return;
    }
    try {
      await _client!.from('tasks').delete().eq('id', id);
    } catch (e) {
      await _cache.enqueue(PendingMutation(id: _uuid.v4(), table: 'tasks', op: 'delete', payload: {'id': id}, createdAt: DateTime.now()));
    }
  }

  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = List<Task>.from(_tasks);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    for (int i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(position: i);
    }
    _tasks = list;
    _tasksCtrl.add(_tasks);
    await _persistCache();
    if (!isConfigured) return;
    for (final t in _tasks) {
      try {
        await _client!.from('tasks').update({'position': t.position}).eq('id', t.id);
      } catch (_) {}
    }
  }

  // Columns CRUD — insert at specific position with shift
  Future<void> addColumn(ColumnDefinition col) async {
    final sorted = List<ColumnDefinition>.from(_columns)..sort((a, b) => a.position.compareTo(b.position));
    final idx = (col.position).clamp(0, sorted.length);
    final toInsert = ColumnDefinition(id: col.id, label: col.label, type: col.type, position: idx, config: col.config, visibleDays: col.visibleDays);
    sorted.insert(idx, toInsert);
    // reassign positions sequentially 0..n-1
    final reassigned = <ColumnDefinition>[];
    for (int i = 0; i < sorted.length; i++) {
      final c = sorted[i];
      reassigned.add(ColumnDefinition(id: c.id, label: c.label, type: c.type, position: i, config: c.config, visibleDays: c.visibleDays));
    }
    _columns = reassigned;
    _colsCtrl.add(_columns);
    await _persistCache();
    if (!isConfigured) return;
    try {
      // Insert the new column at its reassigned position
      final inserted = _columns.firstWhere((c) => c.id == col.id);
      await _client!.from('column_definitions').insert(inserted.toSupabase(userId!));
      // Update positions of columns that shifted (those after idx)
      for (final c in _columns.where((c) => c.id != col.id)) {
        await _client!.from('column_definitions').update({'position': c.position}).eq('id', c.id);
      }
    } catch (e) {
      await _cache.enqueue(PendingMutation(id: _uuid.v4(), table: 'column_definitions', op: 'insert', payload: col.toSupabase(userId!), createdAt: DateTime.now()));
    }
  }

  Future<void> updateColumn(ColumnDefinition col) async {
    final old = _columns.where((e) => e.id == col.id).firstOrNull;
    final typeChanged = old != null && old.type != col.type;
    _columns = _columns.map((e) => e.id == col.id ? col : e).toList();
    _colsCtrl.add(_columns);
    // If type changed, clear or best-effort convert existing cell values for that column
    if (typeChanged) {
      bool cleared = false;
      for (int i = 0; i < _entries.length; i++) {
        final e = _entries[i];
        if (e.data.containsKey(col.id)) {
          final raw = e.data[col.id];
          dynamic converted;
          // best-effort conversion: keep string for text/number/timer, bool for checkbox, etc.
          if (raw != null) {
            try {
              switch (col.type) {
                case ColumnType.text:
                case ColumnType.number:
                  converted = raw.toString();
                  break;
                case ColumnType.checkbox:
                  converted = raw == true || raw == 'true' || raw == 1;
                  break;
                case ColumnType.status:
                  final opts = col.statusOptions.map((o) => o.id).toSet();
                  converted = opts.contains(raw.toString()) ? raw.toString() : null;
                  break;
                case ColumnType.tags:
                  converted = raw is List ? raw : null;
                  break;
                case ColumnType.timer:
                  if (raw is Map) {
                    converted = raw;
                  } else if (raw is String) {
                    final sec = _parseDurationToSec(raw);
                    if (sec > 0) converted = {'durationSec': sec, 'elapsedSec': 0, 'running': false, 'startedAtIso': null};
                  } else {
                    converted = null;
                  }
                  break;
                case ColumnType.schedule:
                  if (raw is String) {
                    // keep time string like "09:00" or "9:00 AM"
                    converted = raw;
                  } else {
                    converted = null;
                  }
                  break;
                default:
                  converted = null;
              }
            } catch (_) {
              converted = null;
            }
          }
          Map<String, dynamic> newData = Map<String, dynamic>.from(e.data);
          if (converted == null) {
            newData.remove(col.id);
          } else {
            newData[col.id] = converted;
          }
          if (newData.length != e.data.length || (converted != null && newData[col.id] != raw)) cleared = true;
          _entries[i] = DayEntry(id: e.id, taskId: e.taskId, userId: e.userId, date: e.date, checked: e.checked, data: newData);
          // also upsert to remote (throttled via normal queue)
          if (!isConfigured) {
            // demo: keep in memory, will be persisted via _persistCache below
          } else {
            // enqueue upsert for changed entries
            try {
              await _client!.from('day_entries').upsert(_entries[i].toSupabase());
            } catch (_) {
              await _cache.enqueue(PendingMutation(id: _uuid.v4(), table: 'day_entries', op: 'upsert', payload: _entries[i].toSupabase(), createdAt: DateTime.now()));
            }
          }
        }
      }
      if (cleared) {
        _entriesCtrl.add(_entries);
      }
    }
    await _persistCache();
    if (!isConfigured) return;
    try {
      await _client!.from('column_definitions').update({'label': col.label, 'type': col.type.name, 'position': col.position, 'config': col.config, 'visible_days': col.visibleDays}).eq('id', col.id);
    } catch (e) {
      await _cache.enqueue(PendingMutation(id: _uuid.v4(), table: 'column_definitions', op: 'update', payload: col.toSupabase(userId!), createdAt: DateTime.now()));
    }
  }

  int _parseDurationToSec(String raw) {
    var s = raw.trim().toLowerCase();
    if (s.isEmpty) return 0;
    int total = 0;
    final re = RegExp(r'(\d+(?:\.\d+)?)\s*(h|hour|hours|hr|m|min|mins|minutes|s|sec|seconds)?');
    for (final m in re.allMatches(s)) {
      final v = double.tryParse(m.group(1)!) ?? 0;
      final unit = m.group(2) ?? 'm';
      if (unit.startsWith('h')) total += (v * 3600).round();
      else if (unit.startsWith('s')) total += v.round();
      else total += (v * 60).round();
    }
    return total;
  }

  Future<void> deleteColumn(String id) async {
    _columns = _columns.where((e) => e.id != id).toList();
    _colsCtrl.add(_columns);
    await _persistCache();
    if (!isConfigured) return;
    try {
      await _client!.from('column_definitions').delete().eq('id', id);
    } catch (e) {
      await _cache.enqueue(PendingMutation(id: _uuid.v4(), table: 'column_definitions', op: 'delete', payload: {'id': id}, createdAt: DateTime.now()));
    }
  }

  Future<void> reorderColumns(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = List<ColumnDefinition>.from(_columns)..sort((a, b) => a.position.compareTo(b.position));
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    for (int i = 0; i < list.length; i++) {
      list[i] = ColumnDefinition(id: list[i].id, label: list[i].label, type: list[i].type, position: i, config: list[i].config, visibleDays: list[i].visibleDays);
    }
    _columns = list;
    _colsCtrl.add(_columns);
    await _persistCache();
    if (!isConfigured) return;
    for (final c in _columns) {
      try {
        await _client!.from('column_definitions').update({'position': c.position}).eq('id', c.id);
      } catch (_) {}
    }
  }

  // DayEntries upsert
  DayEntry? entryFor(String taskId, DateTime date) {
    final k = DayEntry.dateToKey(date);
    try {
      return _entries.firstWhere((e) => e.taskId == taskId && e.dateKey == k);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertEntry(DayEntry entry) async {
    final idx = _entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _entries[idx] = entry;
    } else {
      _entries = [..._entries, entry];
    }
    _entriesCtrl.add(_entries);
    await _persistCache();
    if (!isConfigured) return;
    try {
      await _client!.from('day_entries').upsert(entry.toSupabase());
    } catch (e) {
      await _cache.enqueue(PendingMutation(id: _uuid.v4(), table: 'day_entries', op: 'upsert', payload: entry.toSupabase(), createdAt: DateTime.now()));
    }
  }

  Future<void> toggleChecked(String taskId, DateTime date, bool value) async {
    final statusCol = _columns.where((c) => c.type == ColumnType.status).firstOrNull;
    final existing = entryFor(taskId, date);
    if (existing != null) {
      // keep existing data but ensure default status 'none' when scheduling and no status yet
      var updated = existing.copyWith(checked: value);
      if (value && statusCol != null && !updated.data.containsKey(statusCol.id)) {
        updated = updated.withValue(statusCol.id, 'none');
      }
      await upsertEntry(updated);
    } else {
      final data = <String, dynamic>{};
      if (value && statusCol != null) data[statusCol.id] = 'none';
      final e = DayEntry(id: _uuid.v4(), taskId: taskId, userId: userId!, date: DateTime(date.year, date.month, date.day), checked: value, data: data);
      await upsertEntry(e);
    }
  }

  Future<void> setCellValue(String taskId, DateTime date, String columnId, dynamic value) async {
    final existing = entryFor(taskId, date);
    if (existing != null) {
      await upsertEntry(existing.withValue(columnId, value));
    } else {
      final e = DayEntry(id: _uuid.v4(), taskId: taskId, userId: userId!, date: DateTime(date.year, date.month, date.day), checked: false, data: {columnId: value});
      await upsertEntry(e);
    }
    // Auto-sync status from timer: if this was a timer column, update status column
    final col = _columns.where((c) => c.id == columnId).firstOrNull;
    if (col != null && col.type == ColumnType.timer) {
      await _autoSyncStatus(taskId, date);
    }
  }

  Future<void> _autoSyncStatus(String taskId, DateTime date) async {
    final statusCol = _columns.where((c) => c.type == ColumnType.status).firstOrNull;
    final timerCol = _columns.where((c) => c.type == ColumnType.timer).firstOrNull;
    if (statusCol == null || timerCol == null) return;
    final entry = entryFor(taskId, date);
    if (entry == null) return;
    final raw = entry.data[timerCol.id];
    final tv = TimerValue.tryParse(raw);
    if (tv == null || tv.durationSec == 0) return;
    String? desired;
    if (tv.running) {
      desired = 'in_progress';
    } else if (tv.isComplete) {
      desired = 'done';
    } else {
      return; // keep manual status when paused/stopped with remaining
    }
    final cur = entry.data[statusCol.id] as String?;
    if (cur == desired) return;
    // avoid recursion: directly upsert status without triggering timer sync
    final existing = entryFor(taskId, date);
    if (existing != null) {
      await upsertEntry(existing.withValue(statusCol.id, desired));
    }
  }

  Timer? _statusTicker;
  void _startStatusTicker() {
    _statusTicker?.cancel();
    _statusTicker = Timer.periodic(const Duration(seconds: 1), (_) async {
      final statusCol = _columns.where((c) => c.type == ColumnType.status).firstOrNull;
      final timerCol = _columns.where((c) => c.type == ColumnType.timer).firstOrNull;
      if (statusCol == null || timerCol == null) return;
      final now = DateTime.now();
      for (final e in List<DayEntry>.from(_entries)) {
        final raw = e.data[timerCol.id];
        final tv = TimerValue.tryParse(raw);
        if (tv == null || !tv.running) continue;
        if (tv.effectiveElapsed(now) >= tv.durationSec && tv.durationSec > 0) {
          // timer completed while running -> mark done and stop timer
          final completed = tv.paused(now); // freeze at duration
          // persist timer as completed (not running, elapsed = duration)
          final updatedEntry = e.withValue(timerCol.id, completed.toJson());
          // status to done
          final withStatus = updatedEntry.withValue(statusCol.id, 'done');
          await upsertEntry(withStatus);
        } else if (tv.running) {
          // still running -> ensure status is in_progress
          final curStatus = e.data[statusCol.id] as String?;
          if (curStatus != 'in_progress') {
            await upsertEntry(e.withValue(statusCol.id, 'in_progress'));
          }
        }
      }
    });
  }

  Future<void> _flushQueue() async {
    if (!isConfigured) return;
    final q = await _cache.loadQueue();
    if (q.isEmpty) return;
    final conn = await Connectivity().checkConnectivity();
    if (conn.contains(ConnectivityResult.none)) return;
    final remaining = <PendingMutation>[];
    for (final m in q) {
      try {
        switch (m.table) {
          case 'tasks':
            if (m.op == 'insert') await _client!.from('tasks').insert(m.payload);
            if (m.op == 'update') await _client!.from('tasks').update(m.payload).eq('id', m.payload['id']);
            if (m.op == 'delete') await _client!.from('tasks').delete().eq('id', m.payload['id']);
            break;
          case 'column_definitions':
            if (m.op == 'insert') await _client!.from('column_definitions').insert(m.payload);
            if (m.op == 'update') await _client!.from('column_definitions').update(m.payload).eq('id', m.payload['id']);
            if (m.op == 'delete') await _client!.from('column_definitions').delete().eq('id', m.payload['id']);
            break;
          case 'day_entries':
            if (m.op == 'upsert' || m.op == 'insert') await _client!.from('day_entries').upsert(m.payload);
            if (m.op == 'update') await _client!.from('day_entries').update(m.payload).eq('id', m.payload['id']);
            break;
        }
      } catch (e) {
        remaining.add(m);
      }
    }
    await _cache.saveQueue(remaining);
    await _fetchAll();
  }

  // Demo seed
  Future<void> _initDemo() async {
    if (_demoInit) return;
    _demoInit = true;
    _demoCols.clear();
    _demoCols.addAll(ColumnDefinition.defaultColumns());
    _columns = List.from(_demoCols);
    _colsCtrl.add(_columns);
    // seed tasks like screenshot
    final names = ['Typing', 'reading', 'gym', 'English', 'Solidworks', '', '', '', '', '', '', ''];
    for (int i = 0; i < names.length; i++) {
      final display = names[i].isEmpty ? 'Task ${i + 1}' : names[i];
      // keep empty tasks as placeholder? seed only first 5
      if (i < 5) {
        _demoTasks.add(Task(id: 'task_$i', name: display, position: i, createdAt: DateTime.now(), userId: _demoUserId));
      } else if (i < 7) {
        _demoTasks.add(Task(id: 'task_$i', name: '', position: i, createdAt: DateTime.now(), userId: _demoUserId));
      }
    }
    _tasks = List.from(_demoTasks);
    _tasksCtrl.add(_tasks);
    // seed entries matching screenshot: Tue 9/22, Wed 9/23 etc 2026
    final tue = DateTime(2026, 9, 22);
    final wed = DateTime(2026, 9, 23);
    final fri = DateTime(2026, 9, 25);
    _demoEntries.add(DayEntry(id: _uuid.v4(), taskId: 'task_0', userId: _demoUserId, date: tue, checked: false, data: {'col_status': 'cancel'}));
    _demoEntries.add(DayEntry(id: _uuid.v4(), taskId: 'task_0', userId: _demoUserId, date: wed, checked: true, data: {'col_time': '4h'}));
    _demoEntries.add(DayEntry(id: _uuid.v4(), taskId: 'task_2', userId: _demoUserId, date: wed, checked: false, data: {'col_status': 'done'}));
    _demoEntries.add(DayEntry(id: _uuid.v4(), taskId: 'task_4', userId: _demoUserId, date: tue, checked: true, data: {'col_time': '8h', 'col_status': 'none'}));
    _demoEntries.add(DayEntry(id: _uuid.v4(), taskId: 'task_4', userId: _demoUserId, date: wed, checked: true, data: {'col_time': '48h'}));
    _demoEntries.add(DayEntry(id: _uuid.v4(), taskId: 'task_4', userId: _demoUserId, date: fri, checked: true, data: {'col_time': '30min'}));
    _demoEntries.add(DayEntry(id: _uuid.v4(), taskId: 'task_1', userId: _demoUserId, date: tue, checked: true, data: {'col_time': '4h'}));
    _entries = List.from(_demoEntries);
    _ensureDefaultStatusForAll();
    _entriesCtrl.add(_entries);
    _demoLoggedIn = true;
  }

  void dispose() {
    _statusTicker?.cancel();
    _tasksCtrl.close();
    _colsCtrl.close();
    _entriesCtrl.close();
    _connSub?.cancel();
    _unsubscribe();
  }
}
