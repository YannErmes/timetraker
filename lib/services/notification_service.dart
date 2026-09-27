import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzData;

import 'web_notify.dart';

const _kNotifEnabled = 'notif_enabled';
const _kTimerDone = 'notif_timer_done';
const _kDailyDigest = 'notif_daily_digest';
const _kDailyTime = 'notif_daily_time'; // "08:00"
const _kTimerReminder = 'notif_timer_reminder';
const _kTimerReminderMin = 'notif_timer_reminder_min'; // 5

const _kTaskReminderJobs = 'task_reminder_jobs';
const _kTaskReminderFired = 'task_reminder_fired';
const _kDigestFiredDay = 'notif_digest_fired_day';

class AppNotificationSettings {
  final bool enabled;
  final bool timerDone;
  final bool dailyDigest;
  final String dailyTime; // HH:mm
  final bool timerReminder;
  final int reminderMinutes; // 5
  const AppNotificationSettings({
    this.enabled = true,
    this.timerDone = true,
    this.dailyDigest = true,
    this.dailyTime = '08:00',
    this.timerReminder = false,
    this.reminderMinutes = 5,
  });
  AppNotificationSettings copyWith({bool? enabled, bool? timerDone, bool? dailyDigest, String? dailyTime, bool? timerReminder, int? reminderMinutes}) =>
      AppNotificationSettings(
        enabled: enabled ?? this.enabled,
        timerDone: timerDone ?? this.timerDone,
        dailyDigest: dailyDigest ?? this.dailyDigest,
        dailyTime: dailyTime ?? this.dailyTime,
        timerReminder: timerReminder ?? this.timerReminder,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      );
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  /// System-locale check for notification strings (no BuildContext here).
  static bool get _isFr {
    try {
      return PlatformDispatcher.instance.locale.languageCode == 'fr';
    } catch (_) {
      return false;
    }
  }
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  /// The plugin has no web implementation, and it can be missing on stripped
  /// desktop builds: every plugin call is guarded by this flag and the
  /// in-app scheduler below keeps working without it.
  bool _pluginOk = false;
  String _lastPluginError = '';

  AppNotificationSettings? _settings;

  /// In-app delivery: works on web, Windows and mobile while the app runs.
  Timer? _ticker;
  Timer? _nearest;
  bool _ticking = false;
  final Map<String, TaskReminderJob> _jobs = {};
  final Set<String> _fired = {};

  /// 'granted' | 'denied' | 'default' | 'unavailable'
  String get permissionStatus => kIsWeb ? webNotifPermission : (_pluginOk ? 'granted' : 'unavailable');

  /// Last plugin error, shown in the settings panel when alerts cannot be
  /// delivered natively.
  String get pluginError => _lastPluginError;

  /// Ask for permission. Must be triggered by a user gesture on the web.
  Future<String> requestPermission() async {
    if (kIsWeb) {
      final r = await requestWebNotifPermission();
      debugPrint('web notification permission: $r');
      return r;
    }
    await _requestPermissions();
    return permissionStatus;
  }

  /// Nearest alert the in-app scheduler will deliver, for the settings UI.
  DateTime? get nextFireAt => nextJob?.fireAt;

  /// Nearest pending alert (with its task + label) so the UI can name the
  /// exact time instead of a bare "in 10 h".
  TaskReminderJob? get nextJob {
    final now = DateTime.now();
    TaskReminderJob? best;
    for (final j in _jobs.values) {
      if (_fired.contains(j.firedKey)) continue;
      if (!j.fireAt.isAfter(now)) continue;
      if (best == null || j.fireAt.isBefore(best.fireAt)) best = j;
    }
    return best;
  }

  /// Stop the in-app timers. A widget test cannot finish while the 20s ticker
  /// and the nearest-alarm timer are still pending.
  @visibleForTesting
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _nearest?.cancel();
    _nearest = null;
  }

  Future<void> init() async {
    if (_inited) return;
    tzData.initializeTimeZones();
    // try to set local location to UTC for web, device local for mobile is not critical for immediate
    try {
      tz.setLocalLocation(tz.getLocation('UTC'));
    } catch (_) {}

    if (!kIsWeb) {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      const init = InitializationSettings(android: android, iOS: ios);
      try {
        await _plugin.initialize(init, onDidReceiveNotificationResponse: (r) {
          debugPrint('notif tapped: ${r.payload}');
        });
        _pluginOk = true;
        await _requestPermissions();
      } catch (e) {
        _pluginOk = false;
        _lastPluginError = '$e';
        debugPrint('notif plugin init failed: $e');
      }
    }

    _inited = true;
    await _loadFired();
    _startTicker();
    // Catch up on anything that came due while the app was closed.
    unawaited(_loadPersistedJobs());
    final s = await getSettings();
    if (s.enabled && s.dailyDigest) {
      unawaited(scheduleDailyDigest(s.dailyTime));
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('notif permissions failed: $e');
    }
  }

  Future<AppNotificationSettings> getSettings() async {
    if (_settings != null) return _settings!;
    final p = await SharedPreferences.getInstance();
    return _settings = AppNotificationSettings(
      enabled: p.getBool(_kNotifEnabled) ?? true,
      timerDone: p.getBool(_kTimerDone) ?? true,
      dailyDigest: p.getBool(_kDailyDigest) ?? true,
      dailyTime: p.getString(_kDailyTime) ?? '08:00',
      timerReminder: p.getBool(_kTimerReminder) ?? false,
      reminderMinutes: p.getInt(_kTimerReminderMin) ?? 5,
    );
  }

  Future<void> saveSettings(AppNotificationSettings s) async {
    _settings = s;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifEnabled, s.enabled);
    await p.setBool(_kTimerDone, s.timerDone);
    await p.setBool(_kDailyDigest, s.dailyDigest);
    await p.setString(_kDailyTime, s.dailyTime);
    await p.setBool(_kTimerReminder, s.timerReminder);
    await p.setInt(_kTimerReminderMin, s.reminderMinutes);
    if (s.enabled && s.dailyDigest) {
      await scheduleDailyDigest(s.dailyTime);
    } else {
      await cancelDailyDigest();
    }
  }

  /// 'sent' | 'blocked' | 'unavailable'
  Future<String> showImmediate({required String title, required String body, String? payload, bool respectSettings = true}) async {
    if (respectSettings) {
      final settings = await getSettings();
      if (!settings.enabled) return 'blocked';
    }
    if (kIsWeb) {
      final ok = showWebNotif(title: title, body: body, tag: payload);
      debugPrint('web notif ${ok ? 'shown' : 'refused'}: $title / $body');
      return ok ? 'sent' : 'blocked';
    }
    if (!_pluginOk) {
      debugPrint('notif unavailable (no plugin): $title');
      return 'unavailable';
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails('tracker_sheet_main', '4cus', channelDescription: 'Task reminders', importance: Importance.high, priority: Priority.high),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(DateTime.now().millisecondsSinceEpoch % 100000, title, body, details, payload: payload);
      return 'sent';
    } catch (e) {
      _lastPluginError = '$e';
      debugPrint('notif show failed: $e');
      return 'unavailable';
    }
  }

  /// Test helper for the settings panel: never blocked by individual toggles.
  Future<String> showTest({required String title, required String body}) =>
      showImmediate(title: title, body: body, payload: 'test');

  Future<void> showTimerDone(String taskName) async {
    final s = await getSettings();
    if (!s.enabled || !s.timerDone) return;
    await showImmediate(
      title: _isFr ? 'Minuteur terminé' : 'Timer done',
      body: _isFr ? '"$taskName" — temps écoulé !' : '"$taskName" — time is up!',
    );
  }

  Future<void> showNextTasks(String body) async {
    final s = await getSettings();
    if (!s.enabled || !s.dailyDigest) return;
    await showImmediate(title: _isFr ? 'Tâches du jour' : "Today's tasks", body: body);
  }

  String get _digestTitle => _isFr ? 'Tâches du jour' : "Today's tasks";
  String get _digestBody => _isFr ? 'Touchez pour voir le programme du jour' : 'Tap to see what’s scheduled for today';

  Future<void> scheduleDailyDigest(String timeHHmm) async {
    _settings ??= (await getSettings()).copyWith(dailyTime: timeHHmm);
    if (kIsWeb || !_pluginOk) {
      // The in-app ticker delivers it while the app is open.
      _clearDigestDay();
      return;
    }
    await cancelDailyDigest();
    final parts = timeHHmm.split(':');
    final h = int.tryParse(parts[0]) ?? 8;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final details = NotificationDetails(
      android: AndroidNotificationDetails('tracker_daily', _isFr ? 'Résumé du jour' : 'Daily digest', channelDescription: _isFr ? 'Tâches du matin' : 'Morning tasks', importance: Importance.high, priority: Priority.high),
      iOS: const DarwinNotificationDetails(),
    );
    // Use next occurrence of that time
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, h, m);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    final tzDate = tz.TZDateTime.from(scheduled, tz.local);
    try {
      await _plugin.zonedSchedule(
        1001,
        _digestTitle,
        _digestBody,
        tzDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_digest',
      );
    } catch (e) {
      debugPrint('scheduleDailyDigest failed (in-app ticker takes over): $e');
    }
  }

  Future<void> cancelDailyDigest() async {
    _clearDigestDay();
    if (kIsWeb || !_pluginOk) return;
    try {
      await _plugin.cancel(1001);
    } catch (_) {}
  }

  // Schedule a one-shot reminder X minutes before timer ends
  Future<void> scheduleTimerReminder({required String taskName, required Duration total, required int minutesBefore}) async {
    final s = await getSettings();
    if (!s.enabled || !s.timerReminder) return;
    final when = DateTime.now().add(total - Duration(minutes: minutesBefore));
    if (when.isBefore(DateTime.now())) return;
    if (kIsWeb || !_pluginOk) {
      // Timers keep the page alive, so an in-process delivery is enough.
      final delay = when.difference(DateTime.now());
      Timer(delay, () => showTimerReminderNow(taskName, minutesBefore));
      return;
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails('tracker_timer', 'Timer reminders', channelDescription: 'Timer reminders', importance: Importance.high, priority: Priority.high),
      iOS: DarwinNotificationDetails(),
    );
    final tzDate = tz.TZDateTime.from(when, tz.local);
    try {
      await _plugin.zonedSchedule(
        DateTime.now().millisecondsSinceEpoch % 90000 + 2000,
        'Coming up',
        '"$taskName" ends in $minutesBefore min',
        tzDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('scheduleTimerReminder failed: $e');
    }
  }

  Future<void> showTimerReminderNow(String taskName, int minutesLeft) async {
    final s = await getSettings();
    if (!s.enabled || !s.timerReminder) return;
    await showImmediate(title: 'Reminder', body: '"$taskName" ends in $minutesLeft min');
  }

  static const _kTaskReminderIds = 'task_reminder_ids';

  /// Reconcile per-task reminder notifications with [desired]: cancel anything
  /// stale, schedule anything new. Ids are stable hashes of the task id.
  Future<void> syncTaskReminders(List<TaskReminderJob> desired) async {
    final settings = await getSettings();
    if (!settings.enabled) {
      await cancelAllTaskReminders();
      return;
    }
    // In-app scheduler (web + desktop + mobile while open).
    _applyJobs(desired);
    if (kIsWeb || !_pluginOk) return;
    final prefs = await SharedPreferences.getInstance();
    final known = prefs.getStringList(_kTaskReminderIds) ?? [];
    final want = desired.map((j) => j.taskId).toSet();
    for (final id in known) {
      if (!want.contains(id)) {
        try {
          await _plugin.cancel(_reminderNotifId(id));
        } catch (_) {}
      }
    }
    final scheduled = <String>[];
    for (final job in desired) {
      try {
        final details = NotificationDetails(
          android: AndroidNotificationDetails('tracker_task', _isFr ? 'Rappels de tâches' : 'Task reminders', channelDescription: _isFr ? 'Rappels avant une tâche' : 'Reminders before a task', importance: Importance.high, priority: Priority.high),
          iOS: const DarwinNotificationDetails(),
        );
        await _plugin.zonedSchedule(
          _reminderNotifId(job.taskId),
          job.taskName,
          job.body ?? (_isFr ? 'Commence dans ${job.label}' : 'Starts in ${job.label}'),
          tz.TZDateTime.from(job.fireAt, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'task_reminder:${job.taskId}',
        );
        scheduled.add(job.taskId);
      } catch (e) {
        debugPrint('scheduleTaskReminder failed: $e');
      }
    }
    await prefs.setStringList(_kTaskReminderIds, scheduled);
  }

  // ---------------------------------------------------------------------
  // In-app delivery (works on every platform while the app is open)
  // ---------------------------------------------------------------------

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 20), (_) => unawaited(_tick()));
  }

  void _applyJobs(List<TaskReminderJob> desired) {
    final now = DateTime.now();
    _jobs
      ..clear()
      ..addEntries(desired.where((j) => j.fireAt.isAfter(now.subtract(const Duration(minutes: 5)))).map((j) => MapEntry(j.occKey, j)));
    _persistJobs();
    _armNearest();
    unawaited(_tick());
  }

  void _armNearest() {
    _nearest?.cancel();
    _nearest = null;
    DateTime? best;
    for (final j in _jobs.values) {
      if (_fired.contains(j.firedKey)) continue;
      if (!j.fireAt.isAfter(DateTime.now())) continue;
      if (j.fireAt.difference(DateTime.now()) > const Duration(days: 30)) continue;
      if (best == null || j.fireAt.isBefore(best)) best = j.fireAt;
    }
    if (best == null) return;
    final delay = best.difference(DateTime.now());
    _nearest = Timer(delay.isNegative ? Duration.zero : delay, () => unawaited(_tick()));
  }

  /// Fires everything that is due; also delivers what was missed while the
  /// app was closed (up to 24 h late).
  Future<void> _tick() async {
    if (_ticking) return;
    _ticking = true;
    try {
      final now = DateTime.now();
      final due = _jobs.values.where((j) => !_fired.contains(j.firedKey) && !j.fireAt.isAfter(now)).toList();
      // Claim them all before the first await so two ticks can never
      // deliver the same reminder twice.
      for (final job in due) {
        _fired.add(job.firedKey);
      }
      if (due.isNotEmpty) {
        await _saveFired();
        _persistJobs();
      }
      for (final job in due) {
        final late = now.difference(job.fireAt);
        if (late > const Duration(hours: 24)) continue;
        final lateTag = late > const Duration(minutes: 2) ? (_isFr ? ' (rappel tardif)' : ' (late reminder)') : '';
        await showImmediate(
          title: job.taskName,
          body: job.body ?? (_isFr ? 'Commence dans ${job.label}$lateTag' : 'Starts in ${job.label}$lateTag'),
          payload: 'task_reminder:${job.taskId}',
        );
      }
      _armNearest();
      await _checkDailyDigest(now);
    } finally {
      _ticking = false;
    }
  }

  /// Next alert inside a short horizon -> nudge the user so they can verify
  /// notifications actually fire (the "2 days before" case).
  List<TaskReminderJob> upcoming({Duration within = const Duration(hours: 24)}) {
    final now = DateTime.now();
    return _jobs.values.where((j) => !_fired.contains(j.firedKey) && j.fireAt.isAfter(now) && j.fireAt.difference(now) <= within).toList()
      ..sort((a, b) => a.fireAt.compareTo(b.fireAt));
  }

  Future<void> _checkDailyDigest(DateTime now) async {
    final s = _settings ?? await getSettings();
    if (!s.enabled || !s.dailyDigest) return;
    final parts = s.dailyTime.split(':');
    final h = int.tryParse(parts[0]) ?? 8;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final today = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kDigestFiredDay) == today) return;
    if (now.hour < h || (now.hour == h && now.minute < m)) return;
    // Opening the app at 22:00 must not pop an 08:00 "Today's tasks": only
    // deliver inside a short window, then wait for tomorrow.
    final scheduled = DateTime(now.year, now.month, now.day, h, m);
    if (now.difference(scheduled) > const Duration(hours: 2)) {
      await prefs.setString(_kDigestFiredDay, today);
      return;
    }
    await prefs.setString(_kDigestFiredDay, today);
    await showImmediate(title: _digestTitle, body: _digestBody, payload: 'daily_digest');
  }

  void _clearDigestDay() {
    unawaited(() async {
      try {
        await (await SharedPreferences.getInstance()).remove(_kDigestFiredDay);
      } catch (_) {}
    }());
  }

  Future<void> _loadFired() async {
    try {
      _fired.addAll((await SharedPreferences.getInstance()).getStringList(_kTaskReminderFired) ?? []);
    } catch (_) {}
  }

  /// Occurrence keys are durable (they embed the day), so a fired reminder
  /// never fires twice. Only the tail is kept to bound the payload.
  Future<void> _saveFired() async {
    try {
      final list = _fired.toList()..sort();
      if (list.length > 500) list.removeRange(0, list.length - 500);
      await (await SharedPreferences.getInstance()).setStringList(_kTaskReminderFired, list);
    } catch (_) {}
  }

  void _persistJobs() {
    final payload = _jobs.values
        .map((j) => {
              'occKey': j.occKey,
              'taskId': j.taskId,
              'taskName': j.taskName,
              'fireAt': j.fireAt.toIso8601String(),
              if (j.dedupeAt != null) 'dedupeAt': j.dedupeAt!.toIso8601String(),
              'label': j.label,
              if (j.body != null) 'body': j.body,
            })
        .toList();
    unawaited(() async {
      try {
        await (await SharedPreferences.getInstance()).setString(_kTaskReminderJobs, jsonEncode(payload));
      } catch (_) {}
    }());
  }

  /// Restore the last known schedule so a reminder that came due while the
  /// app was closed still fires on next launch.
  Future<void> _loadPersistedJobs() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_kTaskReminderJobs);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final restored = <TaskReminderJob>[];
      for (final m in list) {
        final fireAt = DateTime.tryParse(m['fireAt'] as String? ?? '');
        final occKey = m['occKey'] as String?;
        if (fireAt == null || occKey == null) continue;
        restored.add(TaskReminderJob(
          taskId: m['taskId'] as String? ?? occKey,
          occKey: occKey,
          taskName: m['taskName'] as String? ?? '',
          fireAt: fireAt,
          dedupeAt: DateTime.tryParse(m['dedupeAt'] as String? ?? ''),
          label: m['label'] as String? ?? 'reminder',
          body: m['body'] as String?,
        ));
      }
      if (restored.isEmpty) return;
      for (final j in restored) {
        _jobs.putIfAbsent(j.occKey, () => j);
      }
      _armNearest();
      await _tick();
    } catch (e) {
      debugPrint('restored reminders failed: $e');
    }
  }

  Future<void> cancelAllTaskReminders() async {
    _jobs.clear();
    _fired.clear();
    _nearest?.cancel();
    _nearest = null;
    _persistJobs();
    try {
      final prefs = await SharedPreferences.getInstance();
      final known = prefs.getStringList(_kTaskReminderIds) ?? [];
      for (final id in known) {
        try {
          await _plugin.cancel(_reminderNotifId(id));
        } catch (_) {}
      }
      await prefs.remove(_kTaskReminderIds);
      await prefs.remove(_kTaskReminderJobs);
      await prefs.remove(_kTaskReminderFired);
    } catch (_) {}
  }

  /// Stable notification id derived from the task id.
  static int _reminderNotifId(String taskId) {
    int h = 0x811c9dc5;
    for (int i = 0; i < taskId.length; i++) {
      h ^= taskId.codeUnitAt(i);
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return 50000 + (h % 100000);
  }
}

/// One upcoming per-task reminder to notify.
class TaskReminderJob {
  final String taskId;
  final String taskName;
  final DateTime fireAt;
  final String label; // e.g. 3D, 10MI, reminder
  final String? body; // message override (reminder-column cells)

  /// Durable identity of the *occurrence* (not the fire time): a reminder set
  /// for a day that already started still notifies once, but never twice.
  final String occKey;

  /// Moment used for [firedKey]. Equals [fireAt] normally; for a reminder set
  /// late it is the intended moment, so re-arming stays idempotent.
  final DateTime? dedupeAt;

  const TaskReminderJob({
    required this.taskId,
    required this.taskName,
    required this.fireAt,
    required this.label,
    this.body,
    String? occKey,
    this.dedupeAt,
  }) : occKey = occKey ?? taskId;

  /// Occurrence + resolved time: moving a task to another hour re-arms the
  /// alert, while a plain refresh of unchanged data does not re-fire it.
  String get firedKey => '$occKey|${(dedupeAt ?? fireAt).toIso8601String()}';
}
