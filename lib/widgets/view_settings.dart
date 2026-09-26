import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../config/ui_style.dart';
import '../config/app_colors.dart';
import '../providers/app_providers.dart';
import '../providers/display_prefs.dart';
import '../services/google_calendar_service.dart';
import 'column_visibility_bar.dart';
import 'notification_settings.dart';

class ViewSettingsButton extends ConsumerWidget {
  const ViewSettingsButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(Icons.tune, size: 18, color: AppColors.textSecondary),
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
    final t = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
      title: Row(children: [Icon(Icons.tune, size: 18, color: AppColors.accent), SizedBox(width: 8), Text(t.viewDensity, style: TextStyle(color: AppColors.textPrimary))]),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.rowsVisibleLbl, style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: prefs.rowsVisible,
              dropdownColor: AppColors.surface,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(labelText: t.rowsLbl),
              items: [
                DropdownMenuItem(value: 0, child: Text(t.allRowsItem)),
                DropdownMenuItem(value: 5, child: Text(t.rowsCountItem('5'))),
                DropdownMenuItem(value: 10, child: Text(t.rowsCountItem('10'))),
                DropdownMenuItem(value: 15, child: Text(t.rowsCountItem('15'))),
                DropdownMenuItem(value: 20, child: Text(t.rowsCountItem('20'))),
              ],
              onChanged: (v) => ref.read(displayPrefsProvider.notifier).setRowsVisible(v ?? 0),
            ),
            const SizedBox(height: 16),
            Text(t.daysVisibleLbl, style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: prefs.daysVisible,
              dropdownColor: AppColors.surface,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(labelText: t.daysLbl),
              items: [
                DropdownMenuItem(value: 0, child: Text(t.allDaysItem)),
                DropdownMenuItem(value: 3, child: Text(t.daysCountItem('3'))),
                DropdownMenuItem(value: 5, child: Text(t.daysCountItem('5'))),
              ],
              onChanged: (v) => ref.read(displayPrefsProvider.notifier).setDaysVisible(v ?? 0),
            ),
            const SizedBox(height: 16),
            Text(t.cellStyleLbl, style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(t.fullBtn), icon: Icon(Icons.view_agenda_outlined, size: 14)),
                ButtonSegment(value: true, label: Text(t.basicBtn), icon: Icon(Icons.smart_button_outlined, size: 14)),
              ],
              selected: {prefs.basicCells},
              onSelectionChanged: (s) => ref.read(displayPrefsProvider.notifier).setBasicCells(s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 4),
            Text(t.basicHelp, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Text(t.appearanceLbl, style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'dark', label: Text(t.darkBtn), icon: Icon(Icons.dark_mode_outlined, size: 14)),
                ButtonSegment(value: 'light', label: Text(t.lightBtn), icon: Icon(Icons.light_mode_outlined, size: 14)),
                ButtonSegment(value: 'custom', label: Text(t.customBtn), icon: Icon(Icons.image_outlined, size: 14)),
              ],
              selected: {prefs.theme},
              onSelectionChanged: (s) => ref.read(displayPrefsProvider.notifier).setTheme(s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            if (prefs.theme == 'custom') ...[
              const SizedBox(height: 8),
              const _CustomBgSection(),
            ],
            const SizedBox(height: 16),
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            const ColumnVisibilitySection(),
            const SizedBox(height: 12),
            Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: Text(t.columnVisibilityHelp, style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
            const SizedBox(height: 16),
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            const NotificationSettingsSection(),
            const SizedBox(height: 16),
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            const _GoogleCalendarSection(),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: ()=> Navigator.pop(context), child: Text(t.close))],
    );
  }
}

class _CustomBgSection extends ConsumerStatefulWidget {
  const _CustomBgSection();
  @override
  ConsumerState<_CustomBgSection> createState() => _CustomBgSectionState();
}

class _CustomBgSectionState extends ConsumerState<_CustomBgSection> {
  bool _picking = false;

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final bytes = await CustomBg.pick();
      if (bytes != null) {
        await CustomBg.save(bytes);
        ref.read(customBgBytesProvider.notifier).state = bytes;
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final bytes = ref.watch(customBgBytesProvider);
    final brightness = ref.watch(customBgBrightnessProvider);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
              color: AppColors.bg,
              image: bytes != null ? DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover) : null,
            ),
            child: bytes == null ? Icon(Icons.image_outlined, size: 22, color: AppColors.textSecondary) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.customHelp, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Row(children: [
                FilledButton.icon(
                  onPressed: _picking ? null : _pick,
                  icon: _picking
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_rounded, size: 14),
                  label: Text(t.chooseImageBtn, style: const TextStyle(fontSize: 11)),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), textStyle: const TextStyle(fontSize: 11)),
                ),
                if (bytes != null) ...[
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () async {
                      await CustomBg.clear();
                      ref.read(customBgBytesProvider.notifier).state = null;
                    },
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text(t.removeImageBtn, style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.brightness_6_outlined, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Expanded(child: Text(t.brightnessLbl, style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          Text('${(brightness * 100).round()}%', style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        ]),
        Slider(
          value: brightness,
          min: 0.15,
          max: 1.0,
          divisions: 17,
          activeColor: AppColors.accent,
          onChanged: (v) => ref.read(customBgBrightnessProvider.notifier).state = v,
          onChangeEnd: (v) => CustomBg.saveBrightness(v),
        ),
      ]),
    );
  }
}

class _GoogleCalendarSection extends ConsumerStatefulWidget {
  const _GoogleCalendarSection();
  @override
  ConsumerState<_GoogleCalendarSection> createState() => _GoogleCalendarSectionState();
}

class _GoogleCalendarSectionState extends ConsumerState<_GoogleCalendarSection> {
  bool _autoSync = false;
  String? _email;
  bool _connected = false;
  bool _loading = true;
  bool _isVip = false;
  final _vipCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _vipCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final connected = await GoogleCalendarService.instance.isConnected();
    final email = await GoogleCalendarService.instance.getConnectedEmail();
    final auto = await GoogleCalendarService.instance.isAutoSyncEnabled();
    final vip = ref.read(identityServiceProvider).isVipUnlocked;
    if (mounted) setState(() { _connected = connected; _email = email; _autoSync = auto; _isVip = vip; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    if (_loading) return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    // Gate behind VIP
    if (!_isVip) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary), SizedBox(width: 6), Text(t.gcalTitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary))]),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.lock_rounded, size: 14, color: AppColors.textSecondary), SizedBox(width: 6), Text(t.vipRequired, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary))]),
            const SizedBox(height: 4),
            Text(t.vipRequiredText, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _vipCtrl,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(labelText: t.vipKeyLbl, hintText: t.vipKeyHint, prefixIcon: Icon(Icons.workspace_premium_outlined, size: 16)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.lock_open_rounded, size: 14),
                label: Text(t.unlockBtn),
                onPressed: () async {
                  final key = _vipCtrl.text.trim();
                  if (key.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.enterVipKey)));
                    return;
                  }
                  try {
                    await ref.read(identityServiceProvider).setVipKey(key);
                    await _load();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.vipSaved)));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.invalidVipKey('$e'))));
                  }
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(t.addLaterNote, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.accent), SizedBox(width: 6), Text(t.gcalTitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary))]),
      const SizedBox(height: 4),
      Text(t.gcalHelp, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      if (!_connected) ...[
        FilledButton.icon(icon: const Icon(Icons.login_rounded, size: 14), label: Text(t.connectBtn), onPressed: () async {
          try {
            await GoogleCalendarService.instance.connect();
            await _load();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.connectedAs(_email ?? 'Google')), backgroundColor: AppColors.surface));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.connectFailed('$e'))));
          }
        }),
        const SizedBox(height: 6),
        Text(t.connectHelp, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ] else ...[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF22C55E)),
            const SizedBox(width: 6),
            Expanded(child: Text(_email ?? t.connectedAs('Google'), style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            TextButton(onPressed: () async { await GoogleCalendarService.instance.disconnect(); await _load(); }, child: Text(t.disconnectBtn, style: const TextStyle(fontSize: 11))),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.sync_rounded, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(t.autoSyncLbl, style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
          Switch(value: _autoSync, activeColor: AppColors.accent, onChanged: (v) async { await GoogleCalendarService.instance.setAutoSync(v); setState(() => _autoSync = v); }),
        ]),
        Text(t.autoSyncHelp, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    ]);
  }
}
