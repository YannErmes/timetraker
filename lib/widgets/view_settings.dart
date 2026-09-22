import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/display_prefs.dart';
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
          ]),
        ),
      ),
      actions: [TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
