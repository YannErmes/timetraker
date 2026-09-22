import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/display_prefs.dart';
import '../services/google_calendar_service.dart';
import 'column_visibility_bar.dart';

class ViewSettingsButton extends ConsumerWidget {
  const ViewSettingsButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.tune, size: 18, color: AppColors.textSecondary),
      tooltip: 'View density',
      onPressed: () => showDialog(context: context, builder: (_) => const _DensityDialog()),
    );
  }
}

class _DensityDialog extends ConsumerWidget {
  const _DensityDialog();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(displayPrefsProvider);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
      title: const Row(children: [Icon(Icons.tune, size: 18, color: AppColors.accent), SizedBox(width: 8), Text('View density', style: TextStyle(color: AppColors.textPrimary))]),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Rows visible at once', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: prefs.rowsVisible,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Rows'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('All rows')),
                DropdownMenuItem(value: 5, child: Text('5 rows')),
                DropdownMenuItem(value: 10, child: Text('10 rows')),
                DropdownMenuItem(value: 15, child: Text('15 rows')),
                DropdownMenuItem(value: 20, child: Text('20 rows')),
              ],
              onChanged: (v) => ref.read(displayPrefsProvider.notifier).setRowsVisible(v ?? 0),
            ),
            const SizedBox(height: 16),
            const Text('Day-columns visible at once (Weekly)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: prefs.daysVisible,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Days'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('All (7 days)')),
                DropdownMenuItem(value: 3, child: Text('3 days')),
                DropdownMenuItem(value: 5, child: Text('5 days')),
              ],
              onChanged: (v) => ref.read(displayPrefsProvider.notifier).setDaysVisible(v ?? 0),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            const ColumnVisibilitySection(),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: const Text('Column visibility is saved per user. Hide schedule/time/status/note to focus the table — e.g., show only status or only time.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            const _GoogleCalendarSection(),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Close'))],
    );
  }
}

class _GoogleCalendarSection extends StatefulWidget {
  const _GoogleCalendarSection();
  @override
  State<_GoogleCalendarSection> createState() => _GoogleCalendarSectionState();
}

class _GoogleCalendarSectionState extends State<_GoogleCalendarSection> {
  bool _autoSync = false;
  String? _email;
  bool _connected = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final connected = await GoogleCalendarService.instance.isConnected();
    final email = await GoogleCalendarService.instance.getConnectedEmail();
    final auto = await GoogleCalendarService.instance.isAutoSyncEnabled();
    if (mounted) setState(() { _connected = connected; _email = email; _autoSync = auto; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.accent), SizedBox(width: 6), Text('Google Calendar sync', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary))]),
      const SizedBox(height: 4),
      const Text('Sync monthly view (scheduled tasks) to your Google Calendar automatically. Put your Google email, accept the consent screen, and you’re done.', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      if (!_connected) ...[
        FilledButton.icon(icon: const Icon(Icons.login_rounded, size: 14), label: const Text('Connect Google Calendar'), onPressed: () async {
          try {
            await GoogleCalendarService.instance.connect();
            await _load();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connected as ${_email ?? 'Google'}'), backgroundColor: AppColors.surface));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connect failed: $e')));
          }
        }),
        const SizedBox(height: 6),
        const Text('You’ll be asked to pick your Google account and Accept calendar access.', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ] else ...[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF22C55E)),
            const SizedBox(width: 6),
            Expanded(child: Text(_email ?? 'Connected', style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            TextButton(onPressed: () async { await GoogleCalendarService.instance.disconnect(); await _load(); }, child: const Text('Disconnect', style: TextStyle(fontSize: 11))),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.sync_rounded, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          const Expanded(child: Text('Auto-sync monthly', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
          Switch(value: _autoSync, activeColor: AppColors.accent, onChanged: (v) async { await GoogleCalendarService.instance.setAutoSync(v); setState(() => _autoSync = v); }),
        ]),
        const Text('When on, every checkbox / schedule / time change for a scheduled day creates/updates a Google event within seconds.', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    ]);
  }
}
