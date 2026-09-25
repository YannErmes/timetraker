import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/google_config.dart';
import '../models/task.dart';
import '../models/day_entry.dart';
import 'identity_service.dart';

const _kAutoSyncKey = 'google_auto_sync';
const _kGoogleEventPrefix = '__gcal_event_id_';
const _kVipKey = 'tracker_vip_key';

/// System-locale fallback for calendar event titles (no BuildContext here).
String _untitledFallback() {
  try {
    if (PlatformDispatcher.instance.locale.languageCode == 'fr') return 'Sans titre';
  } catch (_) {}
  return 'Untitled';
}

class GoogleCalendarService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: hasGoogleClientId ? googleClientId : null,
    scopes: [CalendarApi.calendarScope],
  );

  // Singleton for provider
  static final GoogleCalendarService instance = GoogleCalendarService._();
  GoogleCalendarService._();

  bool get isSupported => true;

  Future<bool> isConnected() async {
    final acc = await _googleSignIn.signInSilently();
    return acc != null;
  }

  Future<String?> getConnectedEmail() async {
    final acc = await _googleSignIn.signInSilently();
    return acc?.email;
  }

  Future<bool> isVipUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_kVipKey);
    return key != null && isValidVipKey(key);
  }

  Future<bool> isAutoSyncEnabled() async {
    if (!await isVipUnlocked()) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoSyncKey) ?? false;
  }

  Future<void> setAutoSync(bool v) async {
    if (v && !await isVipUnlocked()) {
      throw Exception('VIP key required for Google Calendar sync');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoSyncKey, v);
  }

  /// Step 1: user puts email implicitly via Google picker -> consent
  Future<GoogleSignInAccount?> connect() async {
    if (!await isVipUnlocked()) {
      throw Exception('VIP key required');
    }
    try {
      final acc = await _googleSignIn.signIn();
      if (acc != null) {
        // enable auto sync by default on connect
        await setAutoSync(true);
      }
      return acc;
    } catch (e) {
      debugPrint('Google connect error: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
    } catch (_) {}
    await setAutoSync(false);
  }

  Future<CalendarApi?> _getCalendarApi() async {
    final acc = await _googleSignIn.signInSilently();
    if (acc == null) return null;
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;
    return CalendarApi(client);
  }

  DateTime _combine(DateTime date, String? scheduleHM) {
    if (scheduleHM == null || scheduleHM.isEmpty) {
      // default 09:00
      return DateTime(date.year, date.month, date.day, 9, 0);
    }
    try {
      final parts = scheduleHM.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1].substring(0, 2));
      return DateTime(date.year, date.month, date.day, h.clamp(0, 23), m.clamp(0, 59));
    } catch (_) {
      return DateTime(date.year, date.month, date.day, 9, 0);
    }
  }

  String _eventKey(String taskId, DateTime date) => '${taskId}_${date.year}-${date.month}-${date.day}';

  // Store Google eventId locally to avoid duplicates (per task+date)
  Future<Map<String, String>> _loadEventMap() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_kGoogleEventPrefix));
    final map = <String, String>{};
    for (final k in keys) {
      final v = prefs.getString(k);
      if (v != null) map[k.substring(_kGoogleEventPrefix.length)] = v;
    }
    return map;
  }

  Future<void> _saveEventId(String key, String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kGoogleEventPrefix$key', eventId);
  }

  Future<void> _removeEventId(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kGoogleEventPrefix$key');
  }

  /// Sync single day entry — called automatically after every toggleChecked/setCellValue if autoSync
  Future<void> syncDay(Task task, DayEntry? entry, {bool assigned = true}) async {
    if (!await isAutoSyncEnabled()) return;
    if (!await isConnected()) return;
    final cal = await _getCalendarApi();
    if (cal == null) return;
    if (entry == null || !assigned) {
      // unscheduled -> delete existing event if any
      final key = _eventKey(task.id, entry?.date ?? DateTime.now());
      final map = await _loadEventMap();
      final eventId = map[key];
      if (eventId != null) {
        try {
          await cal.events.delete('primary', eventId);
        } catch (_) {}
        await _removeEventId(key);
      }
      return;
    }
    final date = entry.date;
    final schedule = entry.data['col_schedule'] as String?;
    final timeRaw = entry.data['col_time'];
    int durationSec = 3600;
    if (timeRaw is Map && timeRaw['durationSec'] is int) {
      durationSec = timeRaw['durationSec'] as int;
    } else if (timeRaw is String) {
      // fallback parse "3h5min"
      durationSec = _parseDuration(timeRaw);
    } else if (timeRaw is Map && timeRaw['durationSec'] is num) {
      durationSec = (timeRaw['durationSec'] as num).toInt();
    }
    if (durationSec <= 0) durationSec = 3600;

    final status = entry.data['col_status'] as String? ?? 'none';
    final note = entry.data['col_note'] as String? ?? '';

    final start = _combine(date, schedule);
    final end = start.add(Duration(seconds: durationSec));

    final key = _eventKey(task.id, date);
    final map = await _loadEventMap();
    final existingId = map[key];

    final event = Event(
      summary: task.name.isEmpty ? _untitledFallback() : task.name,
      description: 'Status: $status${note.isNotEmpty ? '\nNote: $note' : ''}\nFrom 4cus',
      start: EventDateTime(dateTime: start),
      end: EventDateTime(dateTime: end),
      colorId: _colorForStatus(status),
      extendedProperties: EventExtendedProperties(private: {'tracker_task_id': task.id, 'tracker_date': _eventKey(task.id, date)}),
    );

    try {
      if (existingId != null) {
        final updated = await cal.events.update(event, 'primary', existingId);
        if (updated.id != null) await _saveEventId(key, updated.id!);
      } else {
        final created = await cal.events.insert(event, 'primary');
        if (created.id != null) await _saveEventId(key, created.id!);
      }
    } catch (e) {
      debugPrint('Google syncDay error: $e');
      // keep queue for retry? For simplest, just log — next sync will retry
    }
  }

  /// Delete all Google events for a task (when task is deleted in app)
  Future<void> deleteAllForTask(String taskId) async {
    if (!await isAutoSyncEnabled()) return;
    if (!await isConnected()) return;
    final cal = await _getCalendarApi();
    if (cal == null) return;
    final map = await _loadEventMap();
    final keys = map.keys.where((k) => k.startsWith('${taskId}_')).toList();
    for (final k in keys) {
      final eventId = map[k];
      if (eventId == null) continue;
      try {
        await cal.events.delete('primary', eventId);
      } catch (_) {}
      await _removeEventId(k);
    }
  }

  /// Sync whole month (monthly view) — iterates scheduled entries for that month
  Future<int> syncMonth(DateTime month, List<Task> tasks, List<DayEntry> entries, {required bool Function(DayEntry) isAssigned}) async {
    if (!await isConnected()) throw Exception('Not connected to Google');
    final cal = await _getCalendarApi();
    if (cal == null) throw Exception('No Google client');
    final monthEntries = entries.where((e) => isAssigned(e) && e.date.year == month.year && e.date.month == month.month).toList();
    int synced = 0;
    for (final e in monthEntries) {
      final task = tasks.where((t) => t.id == e.taskId).firstOrNull;
      if (task == null) continue;
      await syncDay(task, e, assigned: true);
      synced++;
    }
    // also clean up unscheduled: those that were previously synced but now unchecked will be handled on next syncDay delete
    return synced;
  }

  int _parseDuration(String s) {
    s = s.trim().toLowerCase();
    int total = 0;
    final re = RegExp(r'(\d+(?:\.\d+)?)\s*(h|hour|hours|hr|m|min|mins|minutes|s|sec|seconds)?');
    for (final m in re.allMatches(s)) {
      final v = double.tryParse(m.group(1)!) ?? 0;
      final unit = m.group(2) ?? 'm';
      if (unit.startsWith('h')) total += (v * 3600).round();
      else if (unit.startsWith('s')) total += v.round();
      else total += (v * 60).round();
    }
    if (total == 0) {
      final n = int.tryParse(s);
      if (n != null) total = n * 60;
    }
    return total == 0 ? 3600 : total;
  }

  String? _colorForStatus(String status) {
    switch (status) {
      case 'done':
        return '10'; // green
      case 'in_progress':
      case 'in progress':
        return '5'; // yellow
      case 'cancel':
        return '11'; // red
      default:
        return '8'; // gray
    }
  }
}
