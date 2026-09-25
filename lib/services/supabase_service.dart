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
import 'identity_service.dart';
import 'google_calendar_service.dart';
import 'notification_service.dart';

const _uuid = Uuid();

/// System-locale fallback names for notifications (no BuildContext here).
bool get _isFr {
  try {
    return PlatformDispatcher.instance.locale.languageCode == 'fr';
  } catch (_) {
    return false;
  }
}

String _fallbackTaskName(String? name) {
  if (name != null && name.isNotEmpty) return name;
  return _isFr ? 'Sans titre' : 'Untitled';
}

/// Where the data currently on screen comes from.
enum SyncStatus {
  loading, // contacting the cloud
  cloud, // live Supabase data
  offlineCache, // cloud unreachable, showing last cached data
  demo, // Supabase not configured in this build — local only
  error, // cloud unreachable and nothing cached
}

class SupabaseService {
  final IdentityService _identity;
  final OfflineCache _cache = OfflineCache();

  SupabaseService(this._identity) {
    // listen to identity changes to re-init data for new name
    _identity.stream.listen((ident) async {
      if (ident != null) {
        // new identity logged in -> reload
        await _handleIdentityChange();
      } else {
        // logged out -> clear in-memory and unsubscribe
        _tasks = [];
        _columns = [];
        _entries = [];
        _tasksCtrl.add(_tasks);
        _colsCtrl.add(_columns);
        _entriesCtrl.add(_entries);
        _unsubscribe();
        _statusTicker?.cancel();
      }
    });
  }

  SupabaseClient? get _client => isSupabaseConfigured ? Supabase.instance.client : null;
  bool get isConfigured => isSupabaseConfigured;
  bool get isLoggedIn => _identity.isLoggedIn;
  String? get userId => _identity.userId;

  // Demo mode (no supabase configured) - in-memory per identity
  final Map<String, List<Task>> _demoTasksByUser = {};
  final Map<String, List<ColumnDefinition>> _demoColsByUser = {};
  final Map<String, List<DayEntry>> _demoEntriesByUser = {};

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

  /// Observable sync state for the UI (AppBar icon, banners).
  final ValueNotifier<SyncStatus> syncStatus = ValueNotifier(SyncStatus.loading);
  String? syncError;

  void _setStatus(SyncStatus s, [String? error]) {
    syncError = error;
    if (syncStatus.value != s) syncStatus.value = s;
  }

  RealtimeChannel? _tasksCh;
  RealtimeChannel? _colsCh;
  RealtimeChannel? _entriesCh;
  StreamSubscription? _connSub;

  Future<void> _handleIdentityChange() async {
    // Clear old account instantly (in-memory AND on screen) so the previous
    // account's data is never visible while the new account loads from cloud.
    _tasks = [];
    _columns = [];
    _entries = [];
    _tasksCtrl.add(_tasks);
    _colsCtrl.add(_columns);
    _entriesCtrl.add(_entries);
    await init();
  }

  Future<void> init() async {
    if (!isLoggedIn || userId == null) {
      // not logged in yet — waiting for name entry
      return;
    }
    if (!isConfigured) {
      await _initDemo();
      _setStatus(SyncStatus.demo);
      _startStatusTicker();
      return;
    }
    // Cloud-first: the server is the source of truth for the signed-in email.
    // Local cache is ONLY an offline fallback — it is never shown ahead of
    // fresh server data. This guarantees that switching between multiple
    // accounts on the same device can never leak one account's (or stale)
    // data into another's view.
    _setStatus(SyncStatus.loading);
    try {
      await _fetchAll();
      _setStatus(SyncStatus.cloud);
    } catch (e) {
      debugPrint('cloud fetch failed, falling back to local cache: $e');
      final hadCache = await _loadFromCache();
      if (hadCache) {
        _setStatus(SyncStatus.offlineCache, 'Cloud unreachable — showing last saved data. Pull to retry when online.');
      } else {
        _setStatus(SyncStatus.error, 'Could not reach the cloud and nothing is saved on this device: $e');
      }
    }
    _subscribeRealtime();
    _startStatusTicker();
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((_) => _flushQueue());
  }

  /// Manual refresh straight from the cloud (e.g. pull-to-refresh).
  /// Never reads the cache — server rows for the current user win.
  /// Returns true when fresh cloud data was loaded.
  Future<bool> reloadFromCloud() async {
    if (!isLoggedIn || userId == null || !isConfigured) return false;
    _setStatus(SyncStatus.loading);
    try {
      await _fetchAll();
      _setStatus(SyncStatus.cloud);
      return true;
    } catch (e) {
      debugPrint('reloadFromCloud failed: $e');
      _setStatus(SyncStatus.error, 'Reload failed — still showing previous data: $e');
      return false;
    }
  }

  /// Loads this user's last cached rows (offline fallback).
  /// Returns true if any cached rows for the current user were found.
  Future<bool> _loadFromCache() async {
    var found = false;
    try {
      final tRows = await _cache.loadTasks();
      final cRows = await _cache.loadColumns();
      final eRows = await _cache.loadEntries();
      // filter by current userId
      final uid = userId;
      if (tRows.isNotEmpty && uid != null) {
        final filtered = tRows.where((j) => j['user_id'] == uid).toList();
        if (filtered.isNotEmpty) {
          _tasks = filtered.map((j) => Task.fromSupabase(Map<String, dynamic>.from(j))).toList()..sort((a, b) => a.position.compareTo(b.position));
          _tasksCtrl.add(_tasks);
          found = true;
        }
      }
      if (cRows.isNotEmpty && uid != null) {
        final filtered = cRows.where((j) => j['user_id'] == uid).toList();
        if (filtered.isNotEmpty) {
          _columns = filtered.map((j) => ColumnDefinition.fromSupabase(Map<String, dynamic>.from(j))).toList()..sort((a, b) => a.position.compareTo(b.position));
          _colsCtrl.add(_columns);
          found = true;
        }
      }
      if (eRows.isNotEmpty && uid != null) {
        final filtered = eRows.where((j) => j['user_id'] == uid).toList();
        if (filtered.isNotEmpty) {
          _entries = filtered.map((j) => DayEntry.fromSupabase(Map<String, dynamic>.from(j))).toList();
          _ensureDefaultStatusForAll();
          _entriesCtrl.add(_entries);
          found = true;
        }
      }
    } catch (e) {
      debugPrint('cache load err $e');
    }
    return found;
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
    }
  }

  Future<void> _persistCache() async {
    if (userId == null) return;
    // For cache we store all users' data together? Use per-user filtered save + merge
    // Simpler: save only current user's data merged with existing cache of other users
    final uid = userId!;
    // Load existing to merge
    try {
      final existingTasks = await _cache.loadTasks();
      final otherTasks = existingTasks.where((j) => j['user_id'] != uid).toList();
      final currentTasks = _tasks.map((t) => {'id': t.id, 'name': t.name, 'position': t.position, 'created_at': t.createdAt.toIso8601String(), 'user_id': t.userId, 'reminder': t.reminder}).toList();
      await _cache.saveTasks([...otherTasks, ...currentTasks]);

      final existingCols = await _cache.loadColumns();
      final otherCols = existingCols.where((j) => j['user_id'] != uid).toList();
      final currentCols = _columns.map((c) => c.toSupabase(uid)).toList();
      await _cache.saveColumns([...otherCols, ...currentCols]);

      final existingEntries = await _cache.loadEntries();
      final otherEntries = existingEntries.where((j) => j['user_id'] != uid).toList();
      final currentEntries = _entries.map((e) => e.toSupabase()).toList();
      await _cache.saveEntries([...otherEntries, ...currentEntries]);
    } catch (_) {
      // fallback to just current
      await _cache.saveTasks(_tasks.map((t) => {'id': t.id, 'name': t.name, 'position': t.position, 'created_at': t.createdAt.toIso8601String(), 'user_id': t.userId, 'reminder': t.reminder}).toList());
      await _cache.saveColumns(_columns.map((c) => c.toSupabase(uid)).toList());
      await _cache.saveEntries(_entries.map((e) => e.toSupabase()).toList());
    }
  }

  void _subscribeRealtime() {
    if (!isConfigured || userId == null) return;
    _unsubscribe();
    final uid = userId!;
    _tasksCh = _client!.channel('tasks-$uid')
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'tasks', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid), callback: (_) => _safeRefresh(_fetchTasks))
      ..subscribe();
    _colsCh = _client!.channel('cols-$uid')
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'column_definitions', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid), callback: (_) => _safeRefresh(_fetchColumns))
      ..subscribe();
    _entriesCh = _client!.channel('entries-$uid')
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'day_entries', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid), callback: (_) => _safeRefresh(_fetchEntries))
      ..subscribe();
  }

  /// Realtime-triggered refresh that never throws and keeps status honest.
  void _safeRefresh(Future<void> Function() fn) {
    fn().then((_) {
      if (isConfigured && syncStatus.value != SyncStatus.loading) {
        _setStatus(SyncStatus.cloud);
      }
    }).catchError((e) {
      debugPrint('realtime refresh failed: $e');
      if (isConfigured && syncStatus.value == SyncStatus.cloud) {
        _setStatus(SyncStatus.offlineCache, 'Lost connection to the cloud — showing last saved data.');
      }
    });
  }

  void _unsubscribe() {
    if (_tasksCh != null && _client != null) _client!.removeChannel(_tasksCh!);
    if (_colsCh != null && _client != null) _client!.removeChannel(_colsCh!);
    if (_entriesCh != null && _client != null) _client!.removeChannel(_entriesCh!);
    _tasksCh = null;
    _colsCh = null;
    _entriesCh = null;
  }

  Future<void> _fetchAll() async {
    await _fetchTasks();
    await _fetchColumns();
    await _fetchEntries();
    _ensureDefaultStatusForAll();
    _entriesCtrl.add(_entries);
    await _persistCache();
    refreshTaskReminders();
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
    if (_columns.isEmpty) {
      final defaults = ColumnDefinition.defaultColumns();
      for (final c in defaults) {
        try {
          // use upsert to be idempotent per (user_id, id) — works after PK fix, and gracefully handles old PK
          await _client!.from('column_definitions').upsert(c.toSupabase(userId!), onConflict: 'user_id,id');
        } catch (_) {
          try {
            await _client!.from('column_definitions').insert(c.toSupabase(userId!));
          } catch (e) {
            // ignore duplicate key (old PK) — will be fixed by schema migration
            debugPrint('insert default col ignored duplicate: $e');
          }
        }
      }
      final r2 = await _client!.from('column_definitions').select().eq('user_id', userId!).order('position');
      _columns = (r2 as List).map((j) => ColumnDefinition.fromSupabase(Map<String, dynamic>.from(j))).toList();
    } else {
      bool needsRefetch = false;
      final hasSchedule = _columns.any((c) => c.id == 'col_schedule');
      if (!hasSchedule) {
        final schedule = ColumnDefinition.defaultColumns().firstWhere((c) => c.id == 'col_schedule');
        for (final c in _columns) {
          try {
            await _client!.from('column_definitions').update({'position': c.position + 1}).eq('id', c.id).eq('user_id', userId!);
          } catch (_) {}
        }
        try {
          await _client!.from('column_definitions').upsert(schedule.toSupabase(userId!), onConflict: 'user_id,id');
        } catch (_) {
          try {
            await _client!.from('column_definitions').insert(schedule.toSupabase(userId!));
          } catch (e) {
            debugPrint('insert schedule ignored: $e');
          }
        }
        needsRefetch = true;
      }
      final hasNote = _columns.any((c) => c.id == 'col_note');
      if (!hasNote) {
        final note = ColumnDefinition.defaultColumns().firstWhere((c) => c.id == 'col_note');
        try {
          await _client!.from('column_definitions').upsert(note.copyWith(position: _columns.length + (hasSchedule ? 0 : 1)).toSupabase(userId!), onConflict: 'user_id,id');
        } catch (_) {
          try {
            await _client!.from('column_definitions').insert(note.copyWith(position: _columns.length + (hasSchedule ? 0 : 1)).toSupabase(userId!));
          } catch (e) {
            debugPrint('insert note ignored: $e');
          }
        }
        needsRefetch = true;
      }
      final timeCol = _columns.where((c) => c.id == 'col_time').firstOrNull;
      if (timeCol != null && timeCol.type != ColumnType.timer) {
        await _client!.from('column_definitions').update({'type': ColumnType.timer.name, 'config': {}}).eq('id', 'col_time').eq('user_id', userId!);
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

  // Tasks CRUD — instant write + queue on failure
  Future<void> addTask(String name) async {
    if (userId == null) return;
    final t = Task(id: _uuid.v4(), name: name, position: _tasks.length, createdAt: DateTime.now(), userId: userId!);
    _tasks = [..._tasks, t];
    _tasksCtrl.add(_tasks);
    await _persistCache();
    if (!isConfigured) {
      final uid = userId!;
      _demoTasksByUser.putIfAbsent(uid, () => []);
      _demoTasksByUser[uid]!.add(t);
      return;
    }
    try {
      await _client!.from('tasks').insert({'id': t.id, 'name': t.name, 'position': t.position, 'user_id': t.userId, 'reminder': t.reminder});
    } catch (e) {
      await _cache.enqueue(PendingMutation(id: _uuid.v4(), table: 'tasks', op: 'insert', payload: {'id': t.id, 'name': t.name, 'position': t.position, 'user_id': t.userId, 'reminder': t.reminder}, createdAt: DateTime.now()));
    }
    refreshTaskReminders();
  }

  Future<void> updateTask(Task t) async {
    _tasks = _tasks.map((e) => e.id == t.id ? t : e).toList();
    _tasksCtrl.add(_tasks);
    await _persistCache();
    if (!isConfigured) return;
    try {
      await _client!.from('tasks').update({'name': t.name, 'position': t.position, 'reminder': t.reminder}).eq('id', t.id).eq('user_id', t.userId);
    } catch (e) {
      await _cache.enqueue(PendingMutation(id: _uuid.v4(), table: 'tasks', op: 'update', payload: {'id': t.id, 'name': t.name, 'position': t.position, 'user_id': t.userId, 'reminder': t.reminder}, createdAt: DateTime.now()));
    }
    refreshTaskReminders();
  }

  Future<void> deleteTask(String id) async {
    final uid = userId;
    _tasks = _tasks.where((e) => e.id != id).toList();
    _tasksCtrl.add(_tasks);
    await _persistCache();
    // also delete Google Calendar events for this task (fire-and-forget)
    unawaited(GoogleCalendarService.instance.deleteAllForTask(id));
    if (!isConfigured) {
      if (uid != null) _demoTasksByUser[uid]?.removeWhere((e) => e.id == id);
      return;
    }
    try {
      var q = _client!.from('tasks').delete().eq('id', id);
      if (uid != null) q = q.eq('user_id', uid);
      await q;
    } catch (e) {
      await _cache.enqueue(PendingMutation(id: _uuid.v4(), table: 'tasks', op: 'delete', payload: {'id': id, 'user_id': uid}, createdAt: DateTime.now()));
    }
    refreshTaskReminders();
  }

  // Columns CRUD — instant
  Future<void> addColumn(ColumnDefinition col) async {
    if (userId == null) return;
    final sorted = List<ColumnDefinition>.from(_columns)..sort((a, b) => a.position.compareTo(b.position));
    final idx = (col.position).clamp(0, sorted.length);
    final toInsert = ColumnDefinition(id: col.id, label: col.label, type: col.type, position: idx, config: col.config, visibleDays: col.visibleDays);
    sorted.insert(idx, toInsert);
    final reassigned = <ColumnDefinition>[];
    for (int i = 0; i < sorted.length; i++) {
      final c = sorted[i];
      reassigned.add(ColumnDefinition(id: c.id, label: c.label, type: c.type, position: i, config: c.config, visibleDays: c.visibleDays));
    }
    _columns = reassigned;
    _colsCtrl.add(_columns);
    await _persistCache();
    if (!isConfigured) {
      final uid = userId!;
      _demoColsByUser.putIfAbsent(uid, () => []);
      _demoColsByUser[uid] = List.from(_columns);
      return;
    }
    try {
      final inserted = _columns.firstWhere((c) => c.id == col.id);
      await _client!.from('column_definitions').insert(inserted.toSupabase(userId!));
      for (final c in _columns.where((c) => c.id != col.id)) {
        await _client!.from('column_definitions').update({'position': c.position}).eq('id', c.id).eq('user_id', userId!);
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
    if (typeChanged) {
      bool cleared = false;
      for (int i = 0; i < _entries.length; i++) {
        final e = _entries[i];
        if (e.data.containsKey(col.id)) {
          final raw = e.data[col.id];
          dynamic converted;
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
                  converted = raw is String ? raw : null;
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
          if (!isConfigured) {
          } else {
            try {
              await _client!.from('day_entries').upsert(_entries[i].toSupabase(), onConflict: 'user_id,task_id,entry_date');
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
      await _client!.from('column_definitions').update({'label': col.label, 'type': col.type.name, 'position': col.position, 'config': col.config, 'visible_days': col.visibleDays}).eq('id', col.id).eq('user_id', userId!);
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
    final uid = userId;
    _columns = _columns.where((e) => e.id != id).toList();
    _colsCtrl.add(_columns);
    await _persistCache();
    if (!isConfigured) {
      if (uid != null) _demoColsByUser[uid] = List.from(_columns);
      return;
    }
    try {
      var q = _client!.from('column_definitions').delete().eq('id', id);
      if (uid != null) q = q.eq('user_id', uid);
      await q;
    } catch (e) {
      await _cache.enqueue(PendingMutation(id: _uuid.v4(), table: 'column_definitions', op: 'delete', payload: {'id': id, 'user_id': uid}, createdAt: DateTime.now()));
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
    final uid = userId;
    for (final c in _columns) {
      try {
        var q = _client!.from('column_definitions').update({'position': c.position}).eq('id', c.id);
        if (uid != null) q = q.eq('user_id', uid);
        await q;
      } catch (_) {}
    }
  }

  // DayEntries — instant + queue on failure
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
    // auto-sync to Google Calendar if enabled (fire-and-forget, never blocks Supabase write)
    unawaited(_maybeSyncToGoogle(entry));
    // recompute task reminders from local state (works offline too)
    refreshTaskReminders();
    if (!isConfigured) return;
    try {
      // Merge with the latest server row so a concurrent edit from another
      // device (phone vs web) touching a different cell of the same day
      // is preserved instead of being wiped by a whole-row overwrite.
      // Local values win per key; checked always reflects this write.
      var payload = entry.toSupabase();
      try {
        final server = await _client!
            .from('day_entries')
            .select()
            .eq('user_id', entry.userId)
            .eq('task_id', entry.taskId)
            .eq('entry_date', entry.dateKey)
            .maybeSingle();
        if (server != null) {
          final serverData = (server['data'] is Map) ? Map<String, dynamic>.from(server['data']) : <String, dynamic>{};
          payload = {
            ...payload,
            'id': (server['id'] as String?) ?? entry.id,
            'checked': entry.checked,
            'data': {...serverData, ...entry.data},
          };
        }
      } catch (_) {
        // merge is best-effort; fall back to direct upsert below
      }
      await _client!.from('day_entries').upsert(payload, onConflict: 'user_id,task_id,entry_date');
    } catch (e) {
      await _cache.enqueue(PendingMutation(id: _uuid.v4(), table: 'day_entries', op: 'upsert', payload: entry.toSupabase(), createdAt: DateTime.now()));
    }
  }

  Future<void> _maybeSyncToGoogle(DayEntry entry) async {
    try {
      if (!await GoogleCalendarService.instance.isAutoSyncEnabled()) return;
      if (!await GoogleCalendarService.instance.isConnected()) return;
      final task = _tasks.where((t) => t.id == entry.taskId).firstOrNull;
      if (task == null) return;
      await GoogleCalendarService.instance.syncDay(task, entry);
    } catch (e) {
      debugPrint('Google auto-sync failed (will retry on next change): $e');
    }
  }

  Future<void> toggleChecked(String taskId, DateTime date, bool value) async {
    if (userId == null) return;
    final statusCol = _columns.where((c) => c.type == ColumnType.status).firstOrNull;
    final existing = entryFor(taskId, date);
    if (existing != null) {
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
    if (userId == null) return;
    final existing = entryFor(taskId, date);
    if (existing != null) {
      await upsertEntry(existing.withValue(columnId, value));
    } else {
      final e = DayEntry(id: _uuid.v4(), taskId: taskId, userId: userId!, date: DateTime(date.year, date.month, date.day), checked: false, data: {columnId: value});
      await upsertEntry(e);
    }
    final col = _columns.where((c) => c.id == columnId).firstOrNull;
    if (col != null && col.type == ColumnType.timer) {
      await _autoSyncStatus(taskId, date);
    }
  }

  /// Reconcile local notifications for per-task reminders (fire-and-forget).
  /// Each task with a valid reminder notifies once before its next scheduled
  /// occurrence (checked entry on/after today at its schedule time).
  void refreshTaskReminders() {
    unawaited(_refreshTaskReminders());
  }

  Future<void> _refreshTaskReminders() async {
    try {
      await NotificationService.instance.syncTaskReminders(_reminderJobs());
    } catch (e) {
      debugPrint('reminder refresh failed: $e');
    }
  }

  List<TaskReminderJob> _reminderJobs() {
    final jobs = <TaskReminderJob>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final schedCol = _columns.where((c) => c.id == 'col_schedule' || c.type == ColumnType.schedule).firstOrNull;
    for (final t in _tasks) {
      final raw = (t.reminder ?? '').trim();
      if (raw.isEmpty) continue;
      final offset = Task.parseReminder(raw);
      if (offset == null) continue;
      final upcoming = _entries
          .where((e) => e.taskId == t.id && e.checked && !e.date.isBefore(today))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      for (final e in upcoming) {
        final when = _occurrenceAt(e.date, schedCol == null ? null : e.data[schedCol.id] as String?);
        final fireAt = when.subtract(offset);
        if (fireAt.isAfter(now)) {
          jobs.add(TaskReminderJob(taskId: t.id, taskName: _fallbackTaskName(t.name), fireAt: fireAt, label: raw.toUpperCase()));
          break;
        }
      }
    }
    // Reminder-column cells: dated messages with their own fire time.
    final remCols = _columns.where((c) => c.type == ColumnType.reminder).toList();
    for (final e in _entries) {
      for (final c in remCols) {
        final raw = e.data[c.id];
        if (raw is! Map) continue;
        final fireAt = DateTime.tryParse(raw['fireAt'] as String? ?? '');
        final msg = (raw['message'] as String? ?? '').trim();
        if (fireAt == null || !fireAt.isAfter(now)) continue;
        final t = _tasks.where((tt) => tt.id == e.taskId).firstOrNull;
        jobs.add(TaskReminderJob(
          taskId: '${e.taskId}:${e.dateKey}:${c.id}',
          taskName: _fallbackTaskName(t?.name),
          fireAt: fireAt,
          label: 'reminder',
          body: msg.isEmpty ? null : msg,
        ));
      }
    }
    return jobs;
  }

  /// Save/clear a reminder-column cell (day + time + message).
  /// Writes the day-entry cell AND upserts the matching `reminders` row
  /// (consumed by the email worker); clearing removes both.
  Future<void> setReminderCell({
    required String taskId,
    required DateTime date,
    required String columnId,
    required DateTime? when,
    required String? message,
  }) async {
    if (userId == null) return;
    final uid = userId!;
    final day = DateTime(date.year, date.month, date.day);
    final dateKey = DayEntry.dateToKey(day);
    final existing = entryFor(taskId, day);
    if (when == null) {
      if (existing != null) {
        await upsertEntry(existing.withValue(columnId, null));
      }
      if (isConfigured) {
        try {
          await _client!.from('reminders').delete().eq('user_id', uid).eq('task_id', taskId).eq('entry_date', dateKey).eq('column_id', columnId);
        } catch (_) {}
      }
    } else {
      final text = (message ?? '').trim();
      final payload = {'fireAt': when.toIso8601String(), 'message': text};
      if (existing != null) {
        await upsertEntry(existing.withValue(columnId, payload));
      } else {
        final e = DayEntry(id: _uuid.v4(), taskId: taskId, userId: uid, date: day, checked: false, data: {columnId: payload});
        await upsertEntry(e);
      }
      if (isConfigured) {
        try {
          await _client!.from('reminders').upsert({
            'user_id': uid,
            'email': _identity.name ?? '',
            'task_id': taskId,
            'entry_date': dateKey,
            'column_id': columnId,
            'fire_at': when.toIso8601String(),
            'message': text,
            'status': 'pending',
          }, onConflict: 'user_id,task_id,entry_date,column_id');
        } catch (e) {
          await _cache.enqueue(PendingMutation(id: _uuid.v4(), table: 'reminders', op: 'upsert', payload: {
            'user_id': uid,
            'email': _identity.name ?? '',
            'task_id': taskId,
            'entry_date': dateKey,
            'column_id': columnId,
            'fire_at': when.toIso8601String(),
            'message': text,
            'status': 'pending',
          }, createdAt: DateTime.now()));
        }
      }
    }
    refreshTaskReminders();
  }

  DateTime _occurrenceAt(DateTime date, String? hhmm) {
    int h = 9, m = 0;
    if (hhmm != null && hhmm.contains(':')) {
      final parts = hhmm.split(':');
      h = int.tryParse(parts[0]) ?? 9;
      if (parts.length > 1) m = int.tryParse(parts[1].substring(0, 2)) ?? 0;
    }
    return DateTime(date.year, date.month, date.day, h, m);
  }

  Future<void> _autoSyncStatus(String taskId, DateTime date) async {    final statusCol = _columns.where((c) => c.type == ColumnType.status).firstOrNull;
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
      return;
    }
    final cur = entry.data[statusCol.id] as String?;
    if (cur == desired) return;
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
          final completed = tv.paused(now);
          final updatedEntry = e.withValue(timerCol.id, completed.toJson());
          final withStatus = updatedEntry.withValue(statusCol.id, 'done');
          await upsertEntry(withStatus);
          // notify: timer done
          final task = _tasks.where((t) => t.id == e.taskId).firstOrNull;
          await NotificationService.instance.showTimerDone(_fallbackTaskName(task?.name));
          // also send next tasks for the day after a short delay
          Future.delayed(const Duration(seconds: 2), () async {
            final nextEntries = _entries.where((en) => en.checked && en.date.year == now.year && en.date.month == now.month && en.date.day == now.day && en.taskId != e.taskId).take(3).toList();
            if (nextEntries.isNotEmpty) {
              final names = nextEntries.map((en) {
                final t = _tasks.where((tt) => tt.id == en.taskId).firstOrNull;
                return _fallbackTaskName(t?.name);
              }).join(', ');
              await NotificationService.instance.showNextTasks('${_isFr ? 'Suivant' : 'Next'}: $names');
            }
          });
        } else if (tv.running) {
          final curStatus = e.data[statusCol.id] as String?;
          if (curStatus != 'in_progress') {
            await upsertEntry(e.withValue(statusCol.id, 'in_progress'));
          }
          // schedule reminder if enabled (only once per start)
          final settings = await NotificationService.instance.getSettings();
          if (settings.enabled && settings.timerReminder) {
            final remaining = tv.durationSec - tv.effectiveElapsed(now);
            final mins = settings.reminderMinutes;
            if (remaining > mins * 60 && remaining < tv.durationSec) {
              final task = _tasks.where((t) => t.id == e.taskId).firstOrNull;
              final total = Duration(seconds: tv.durationSec);
              unawaited(NotificationService.instance.scheduleTimerReminder(taskName: _fallbackTaskName(task?.name), total: total, minutesBefore: mins));
            }
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
        // Scope every replayed mutation by user_id when known so a queued
        // write can never touch another account's rows.
        final pUid = m.payload['user_id'] as String?;
        switch (m.table) {
          case 'tasks':
            if (m.op == 'insert') {
              await _client!.from('tasks').insert(m.payload);
            } else if (m.op == 'update') {
              var uq = _client!.from('tasks').update(m.payload).eq('id', m.payload['id']);
              if (pUid != null) uq = uq.eq('user_id', pUid);
              await uq;
            } else if (m.op == 'delete') {
              var dq = _client!.from('tasks').delete().eq('id', m.payload['id']);
              if (pUid != null) dq = dq.eq('user_id', pUid);
              await dq;
            }
            break;
          case 'column_definitions':
            if (m.op == 'insert') {
              await _client!.from('column_definitions').upsert(m.payload, onConflict: 'user_id,id');
            } else if (m.op == 'update') {
              var uq = _client!.from('column_definitions').update(m.payload).eq('id', m.payload['id']);
              if (pUid != null) uq = uq.eq('user_id', pUid);
              await uq;
            } else if (m.op == 'delete') {
              var dq = _client!.from('column_definitions').delete().eq('id', m.payload['id']);
              if (pUid != null) dq = dq.eq('user_id', pUid);
              await dq;
            }
            break;
          case 'day_entries':
            if (m.op == 'upsert' || m.op == 'insert') {
              await _client!.from('day_entries').upsert(m.payload, onConflict: 'user_id,task_id,entry_date');
            } else if (m.op == 'update') {
              var uq = _client!.from('day_entries').update(m.payload).eq('id', m.payload['id']);
              if (pUid != null) uq = uq.eq('user_id', pUid);
              await uq;
            }
            break;
          case 'reminders':
            if (m.op == 'upsert' || m.op == 'insert') {
              await _client!.from('reminders').upsert(m.payload, onConflict: 'user_id,task_id,entry_date,column_id');
            } else if (m.op == 'delete') {
              var dq = _client!.from('reminders').delete().eq('user_id', m.payload['user_id']).eq('task_id', m.payload['task_id']).eq('entry_date', m.payload['entry_date']);
              await dq;
            }
            break;
          case 'app_users':
            if (m.op == 'insert') await _client!.from('app_users').insert(m.payload);
            break;
        }
      } catch (e) {
        remaining.add(m);
      }
    }
    await _cache.saveQueue(remaining);
    await _fetchAll();
    if (remaining.isEmpty && isConfigured) _setStatus(SyncStatus.cloud);
  }

  // Demo seed per identity
  Future<void> _initDemo() async {
    final uid = userId;
    if (uid == null) return;
    if (_demoColsByUser.containsKey(uid) && _demoColsByUser[uid]!.isNotEmpty) {
      _columns = List.from(_demoColsByUser[uid]!);
      _tasks = List.from(_demoTasksByUser[uid] ?? []);
      _entries = List.from(_demoEntriesByUser[uid] ?? []);
      _colsCtrl.add(_columns);
      _tasksCtrl.add(_tasks);
      _entriesCtrl.add(_entries);
      return;
    }
    _demoColsByUser[uid] = List.from(ColumnDefinition.defaultColumns());
    _columns = List.from(_demoColsByUser[uid]!);
    _colsCtrl.add(_columns);
    final names = ['Typing', 'reading', 'gym', 'English', 'Solidworks', '', '', '', '', '', '', ''];
    final demoTasks = <Task>[];
    for (int i = 0; i < names.length; i++) {
      final display = names[i].isEmpty ? 'Task ${i + 1}' : names[i];
      if (i < 5) {
        demoTasks.add(Task(id: 'task_$i', name: display, position: i, createdAt: DateTime.now(), userId: uid));
      } else if (i < 7) {
        demoTasks.add(Task(id: 'task_$i', name: '', position: i, createdAt: DateTime.now(), userId: uid));
      }
    }
    _demoTasksByUser[uid] = demoTasks;
    _tasks = List.from(demoTasks);
    _tasksCtrl.add(_tasks);
    final tue = DateTime(2026, 9, 22);
    final wed = DateTime(2026, 9, 23);
    final fri = DateTime(2026, 9, 25);
    final demoEntries = <DayEntry>[
      DayEntry(id: _uuid.v4(), taskId: 'task_0', userId: uid, date: tue, checked: false, data: {'col_status': 'cancel'}),
      DayEntry(id: _uuid.v4(), taskId: 'task_0', userId: uid, date: wed, checked: true, data: {'col_time': {'durationSec': 14400, 'elapsedSec': 0, 'running': false, 'startedAtIso': null}, 'col_status': 'none'}),
      DayEntry(id: _uuid.v4(), taskId: 'task_2', userId: uid, date: wed, checked: false, data: {'col_status': 'done'}),
      DayEntry(id: _uuid.v4(), taskId: 'task_4', userId: uid, date: tue, checked: true, data: {'col_time': {'durationSec': 28800, 'elapsedSec': 0, 'running': false, 'startedAtIso': null}, 'col_status': 'none'}),
      DayEntry(id: _uuid.v4(), taskId: 'task_4', userId: uid, date: wed, checked: true, data: {'col_time': {'durationSec': 172800, 'elapsedSec': 0, 'running': false, 'startedAtIso': null}}),
      DayEntry(id: _uuid.v4(), taskId: 'task_4', userId: uid, date: fri, checked: true, data: {'col_time': {'durationSec': 1800, 'elapsedSec': 0, 'running': false, 'startedAtIso': null}}),
      DayEntry(id: _uuid.v4(), taskId: 'task_1', userId: uid, date: tue, checked: true, data: {'col_time': {'durationSec': 14400, 'elapsedSec': 0, 'running': false, 'startedAtIso': null}}),
    ];
    _demoEntriesByUser[uid] = demoEntries;
    _entries = List.from(demoEntries);
    _ensureDefaultStatusForAll();
    _entriesCtrl.add(_entries);
    await _persistCache();
  }

  void dispose() {
    _statusTicker?.cancel();
    syncStatus.dispose();
    _tasksCtrl.close();
    _colsCtrl.close();
    _entriesCtrl.close();
    _connSub?.cancel();
    _unsubscribe();
  }

  // kept for HomeScreen signOut (now delegates to identity)
  Future<void> signOut() async {
    await _identity.signOut();
  }

  /// Sends a user suggestion to the public inbox (Supabase `suggestions`).
  /// Throws on failure so the UI can show the error.
  Future<void> submitSuggestion({required String name, required String message}) async {
    if (!isConfigured) throw StateError('Cloud is not configured in this build.');
    final clean = message.trim();
    if (clean.isEmpty) throw ArgumentError('Please write your suggestion first.');
    await _client!.from('suggestions').insert({
      'id': _uuid.v4(),
      'user_id': userId,
      'name': name.trim(),
      'message': clean,
    });
  }  // legacy email methods kept as no-op for compat (not used)
  Future<void> signUp(String email, String password) async => throw UnimplementedError('Use name-based identity');
  Future<void> signIn(String email, String password) async => throw UnimplementedError('Use name-based identity');
}
