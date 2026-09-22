import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/app_providers.dart';
import '../providers/column_visibility.dart';
import '../models/enums.dart';
import '../utils/date_utils.dart';
import 'cells/cell_widgets.dart';
import 'cells/timer_cell.dart';

class DayDetailPanel extends ConsumerWidget {
  final DateTime date;
  const DayDetailPanel({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(supabaseServiceProvider);
    ref.watch(tasksProvider);
    ref.watch(columnsProvider);
    ref.watch(entriesProvider);
    final allTasks = List.of(svc.tasks)..sort((a, b) => a.position.compareTo(b.position));
    // Monthly filtering: only tasks whose checkbox is checked for this day are scheduled
    final tasks = allTasks.where((t) => (svc.entryFor(t.id, date)?.checked ?? false)).toList();
    final allCols = List.of(svc.columns)..sort((a, b) => a.position.compareTo(b.position));
    final hidden = ref.watch(columnVisibilityProvider);
    final cols = allCols.where((c) => !hidden.contains(c.id)).toList();

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(color: AppColors.header, borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(children: [
            Text('${formatWeekday(date)} ${formatDayHeader(date)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),
        Flexible(
          child: tasks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.event_busy, size: 28, color: AppColors.textSecondary),
                    const SizedBox(height: 8),
                    const Text('No tasks scheduled for this day.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('Check the box for a task in Weekly or Daily view to schedule it for this date.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('${formatWeekday(date)} ${formatDayHeader(date)} — ${allTasks.length} total tasks, none scheduled.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                  ]),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final t = tasks[i];
                    final e = svc.entryFor(t.id, date);
                    final checked = e?.checked ?? false;
                    return Container(
                      decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                      padding: const EdgeInsets.all(10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Checkbox(value: checked, onChanged: (v) => svc.toggleChecked(t.id, date, v ?? false)),
                          Expanded(child: Text(t.name.isEmpty ? 'Untitled' : t.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13))),
                        ]),
                        const SizedBox(height: 8),
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          for (final col in cols)
                            SizedBox(
                              width: 180,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(col.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3)),
                                const SizedBox(height: 4),
                                Builder(builder: (_) {
                                  final raw = e?.valueFor(col.id);
                                  switch (col.type) {
                                    case ColumnType.schedule:
                                      return ScheduleCell(value: raw as String?, onChanged: (v) => svc.setCellValue(t.id, date, col.id, v));
                                    case ColumnType.status:
                                      return StatusCell(valueId: raw as String?, options: col.statusOptions, onChanged: (v) => svc.setCellValue(t.id, date, col.id, v));
                                    case ColumnType.number:
                                    case ColumnType.text:
                                      return DurationCell(value: raw as String?, onChanged: (v) => svc.setCellValue(t.id, date, col.id, v));
                                    case ColumnType.timer:
                                      return TimerCell(taskId: t.id, date: date, columnId: col.id, rawValue: raw);
                                    case ColumnType.checkbox:
                                      return Checkbox(value: raw == true, onChanged: (v) => svc.setCellValue(t.id, date, col.id, v));
                                    case ColumnType.tags:
                                      final ids = raw is List ? List<String>.from(raw) : <String>[];
                                      return TagCell(selectedIds: ids, options: col.tagOptions, onChanged: (v) => svc.setCellValue(t.id, date, col.id, v));
                                    case ColumnType.date:
                                      return InkWell(borderRadius: BorderRadius.circular(8), onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) svc.setCellValue(t.id, date, col.id, d.toIso8601String().split('T').first); }, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)), child: Text(raw ?? '—', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))));
                                    case ColumnType.datetime:
                                      return InkWell(borderRadius: BorderRadius.circular(8), onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null && context.mounted) { final tp = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (tp != null) svc.setCellValue(t.id, date, col.id, DateTime(d.year, d.month, d.day, tp.hour, tp.minute).toIso8601String()); } }, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)), child: Text(raw?.toString().substring(0, 16) ?? '—', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))));
                                  }
                                }),
                              ]),
                            ),
                        ]),
                      ]),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border)), borderRadius: BorderRadius.vertical(bottom: Radius.circular(8))),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            const Expanded(child: Text('Edits save immediately and update the Monthly heatmap.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ]),
        ),
      ]),
    );
  }
}

void showDayDetail(BuildContext context, DateTime date) {
  final isMobile = MediaQuery.of(context).size.width < 600;
  if (isMobile) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => DraggableScrollableSheet(initialChildSize: 0.8, maxChildSize: 0.95, minChildSize: 0.4, builder: (_, ctrl) => Container(decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(12))), child: DayDetailPanel(date: date))));
  } else {
    showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700), child: DayDetailPanel(date: date))));
  }
}
