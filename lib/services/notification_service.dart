import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzData;

const _kNotifEnabled = 'notif_enabled';
const _kTimerDone = 'notif_timer_done';
const _kDailyDigest = 'notif_daily_digest';
const _kDailyTime = 'notif_daily_time'; // "08:00"
const _kTimerReminder = 'notif_timer_reminder';
const _kTimerReminderMin = 'notif_timer_reminder_min'; // 5

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
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    tzData.initializeTimeZones();
    // try to set local location to UTC for web, device local for mobile is not critical for immediate
    try {
      tz.setLocalLocation(tz.getLocation('UTC'));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const init = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(init,
        onDidReceiveNotificationResponse: (r) {
      debugPrint('notif tapped: ${r.payload}');
    });
    _inited = true;
    // request permissions where needed
    await _requestPermissions();
    // reschedule daily if enabled
    final s = await getSettings();
    if (s.enabled && s.dailyDigest) {
      await scheduleDailyDigest(s.dailyTime);
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) {
      // Web Notification permission is handled by browser prompt on first show
      return;
    }
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<AppNotificationSettings> getSettings() async {
    final p = await SharedPreferences.getInstance();
    return AppNotificationSettings(
      enabled: p.getBool(_kNotifEnabled) ?? true,
      timerDone: p.getBool(_kTimerDone) ?? true,
      dailyDigest: p.getBool(_kDailyDigest) ?? true,
      dailyTime: p.getString(_kDailyTime) ?? '08:00',
      timerReminder: p.getBool(_kTimerReminder) ?? false,
      reminderMinutes: p.getInt(_kTimerReminderMin) ?? 5,
    );
  }

  Future<void> saveSettings(AppNotificationSettings s) async {
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

  Future<void> showImmediate({required String title, required String body, String? payload}) async {
    final settings = await getSettings();
    if (!settings.enabled) return;
    // Web: check Notification permission via plugin will prompt if needed
    const details = NotificationDetails(
      android: AndroidNotificationDetails('tracker_sheet_main', 'Tracker Sheet', channelDescription: 'Task reminders', importance: Importance.high, priority: Priority.high),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(DateTime.now().millisecondsSinceEpoch % 100000, title, body, details, payload: payload);
  }

  Future<void> showTimerDone(String taskName) async {
    final s = await getSettings();
    if (!s.enabled || !s.timerDone) return;
    await showImmediate(title: 'Timer done', body: '"$taskName" — time is up!');
  }

  Future<void> showNextTasks(String body) async {
    final s = await getSettings();
    if (!s.enabled || !s.dailyDigest) return;
    await showImmediate(title: "Today's tasks", body: body);
  }

  Future<void> scheduleDailyDigest(String timeHHmm) async {
    await cancelDailyDigest();
    final parts = timeHHmm.split(':');
    final h = int.tryParse(parts[0]) ?? 8;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    const details = NotificationDetails(
      android: AndroidNotificationDetails('tracker_daily', 'Daily digest', channelDescription: 'Morning tasks', importance: Importance.high, priority: Priority.high),
      iOS: DarwinNotificationDetails(),
    );
    // Use next occurrence of that time
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, h, m);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    final tzDate = tz.TZDateTime.from(scheduled, tz.local);
    try {
      await _plugin.zonedSchedule(
        1001,
        "Today's tasks",
        'Tap to see what’s scheduled for today',
        tzDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_digest',
      );
    } catch (e) {
      debugPrint('scheduleDailyDigest failed (web may not support zoned): $e');
      // fallback: schedule via Timer when app is open — not needed for web background
    }
  }

  Future<void> cancelDailyDigest() async {
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
}
