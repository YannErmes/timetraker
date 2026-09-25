import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../services/notification_service.dart';
import '../providers/app_providers.dart';

class NotificationSettingsSection extends ConsumerStatefulWidget {
  const NotificationSettingsSection({super.key});
  @override
  ConsumerState<NotificationSettingsSection> createState() => _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState extends ConsumerState<NotificationSettingsSection> {
  AppNotificationSettings _s = const AppNotificationSettings();
  bool _loading = true;
  bool _testingDaily = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await NotificationService.instance.getSettings();
    await NotificationService.instance.init();
    if (mounted) setState(() { _s = s; _loading = false; });
  }

  Future<void> _save(AppNotificationSettings s) async {
    setState(() => _s = s);
    await NotificationService.instance.saveSettings(s);
  }

  TimeOfDay _parseTime(String hhmm) {
    final p = hhmm.split(':');
    return TimeOfDay(hour: int.tryParse(p[0]) ?? 8, minute: p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  String _fmt(TimeOfDay t) => t.format(context);

  String _dailyBodyForToday(AppLocalizations t) {
    try {
      final svc = ref.read(supabaseServiceProvider);
      final date = ref.read(selectedDateProvider);
      final tasks = svc.tasks;
      final scheduled = svc.entries.where((e) => svc.isAssigned(e) && e.date.year == date.year && e.date.month == date.month && e.date.day == date.day).toList();
      if (scheduled.isEmpty) return t.noTasksToday;
      final names = scheduled.take(4).map((e) {
        final task = tasks.where((tt) => tt.id == e.taskId).firstOrNull;
        final n = task?.name.isNotEmpty == true ? task!.name : t.untitledCap;
        final time = e.data['col_schedule'] as String?;
        return time != null && time.isNotEmpty ? '$n at $time' : n;
      }).join(', ');
      final more = scheduled.length > 4 ? ' +${scheduled.length - 4} more' : '';
      return '$names$more • ${scheduled.length} ${t.scheduledChip.toLowerCase()}';
    } catch (_) {
      return t.tapToSee;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    if (_loading) return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.notifications_rounded, size: 14, color: AppColors.accent),
        const SizedBox(width: 6),
        Text(t.notifTitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const Spacer(),
        Switch(value: _s.enabled, activeColor: AppColors.accent, onChanged: (v) => _save(_s.copyWith(enabled: v))),
      ]),
      const SizedBox(height: 4),
      Text(t.notifHelp, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      const SizedBox(height: 12),
      _tile(
        icon: Icons.hourglass_bottom_rounded,
        title: t.timerDoneTitle,
        subtitle: t.timerDoneSub,
        value: _s.timerDone,
        enabled: _s.enabled,
        onChanged: (v) => _save(_s.copyWith(timerDone: v)),
      ),
      _tile(
        icon: Icons.wb_sunny_rounded,
        title: t.dailyBriefTitle,
        subtitle: t.dailyBriefSub,
        value: _s.dailyDigest,
        enabled: _s.enabled,
        onChanged: (v) => _save(_s.copyWith(dailyDigest: v)),
        trailing: _s.dailyDigest
            ? TextButton(
                onPressed: () async {
                  final time = await showTimePicker(context: context, initialTime: _parseTime(_s.dailyTime));
                  if (time != null) {
                    final hhmm = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                    await _save(_s.copyWith(dailyTime: hhmm));
                  }
                },
                child: Text(_fmt(_parseTime(_s.dailyTime)), style: const TextStyle(fontSize: 12)),
              )
            : null,
      ),
      if (_s.dailyDigest)
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 8),
          child: Row(children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.send_rounded, size: 14),
              label: Text(t.sendTestNow, style: const TextStyle(fontSize: 11)),
              onPressed: _testingDaily
                  ? null
                  : () async {
                      setState(() => _testingDaily = true);
                      await NotificationService.instance.showNextTasks(_dailyBodyForToday(t));
                      if (mounted) setState(() => _testingDaily = false);
                    },
            ),
            const SizedBox(width: 8),
            Text(t.atDaily(_fmt(_parseTime(_s.dailyTime))), style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ),
      _tile(
        icon: Icons.alarm_rounded,
        title: t.timerRemTitle,
        subtitle: t.timerRemSub,
        value: _s.timerReminder,
        enabled: _s.enabled,
        onChanged: (v) => _save(_s.copyWith(timerReminder: v)),
        trailing: _s.timerReminder
            ? DropdownButton<int>(
                value: _s.reminderMinutes,
                dropdownColor: AppColors.surface,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                underline: const SizedBox.shrink(),
                items: [1, 2, 5, 10, 15].map((m) => DropdownMenuItem(value: m, child: Text(t.minSuffix('$m')))).toList(),
                onChanged: _s.enabled ? (v) => _save(_s.copyWith(reminderMinutes: v!)) : null,
              )
            : null,
      ),
    ]);
  }

  Widget _tile({required IconData icon, required String title, required String subtitle, required bool value, required bool enabled, required ValueChanged<bool> onChanged, Widget? trailing}) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 16, color: enabled ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.5)),
      title: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: enabled ? AppColors.textPrimary : AppColors.textSecondary.withValues(alpha: 0.6))),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 10, color: enabled ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.5))),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (trailing != null) trailing,
        Switch(value: value && enabled, activeColor: AppColors.accent, onChanged: enabled ? onChanged : null),
      ]),
    );
  }
}
