import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PendingMutation {
  final String id;
  final String table; // tasks | day_entries | columns
  final String op; // insert | update | delete | upsert
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  PendingMutation({required this.id, required this.table, required this.op, required this.payload, required this.createdAt});
  Map<String, dynamic> toJson() => {'id': id, 'table': table, 'op': op, 'payload': payload, 'createdAt': createdAt.toIso8601String()};
  factory PendingMutation.fromJson(Map<String, dynamic> j) => PendingMutation(
        id: j['id'] as String,
        table: j['table'] as String,
        op: j['op'] as String,
        payload: Map<String, dynamic>.from(j['payload']),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class OfflineCache {
  static const _kTasks = 'cache_tasks';
  static const _kEntries = 'cache_day_entries';
  static const _kColumns = 'cache_columns';
  static const _kQueue = 'cache_queue';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> saveAll(String key, List<Map<String, dynamic>> rows) async {
    final p = await _prefs;
    await p.setString(key, jsonEncode(rows));
  }

  Future<List<Map<String, dynamic>>> loadAll(String key) async {
    final p = await _prefs;
    final s = p.getString(key);
    if (s == null) return [];
    final l = jsonDecode(s) as List;
    return l.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveTasks(List<Map<String, dynamic>> rows) => saveAll(_kTasks, rows);
  Future<void> saveEntries(List<Map<String, dynamic>> rows) => saveAll(_kEntries, rows);
  Future<void> saveColumns(List<Map<String, dynamic>> rows) => saveAll(_kColumns, rows);

  Future<List<Map<String, dynamic>>> loadTasks() => loadAll(_kTasks);
  Future<List<Map<String, dynamic>>> loadEntries() => loadAll(_kEntries);
  Future<List<Map<String, dynamic>>> loadColumns() => loadAll(_kColumns);

  Future<List<PendingMutation>> loadQueue() async {
    final p = await _prefs;
    final s = p.getString(_kQueue);
    if (s == null) return [];
    final l = jsonDecode(s) as List;
    return l.map((e) => PendingMutation.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> saveQueue(List<PendingMutation> q) async {
    final p = await _prefs;
    await p.setString(_kQueue, jsonEncode(q.map((e) => e.toJson()).toList()));
  }

  Future<void> enqueue(PendingMutation m) async {
    final q = await loadQueue();
    q.add(m);
    await saveQueue(q);
  }

  Future<void> clearQueue() async {
    final p = await _prefs;
    await p.remove(_kQueue);
  }
}
