import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/app_providers.dart';
import '../providers/column_visibility.dart';
import '../models/enums.dart';
import 'cells/cell_widgets.dart';
import 'cells/timer_cell.dart';

class AndroidChecklist extends ConsumerWidget {
  const AndroidChecklist({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(supabaseServiceProvider);
    ref.watch(tasksProvider);
    ref.watch(columnsProvider);
    ref.watch(entriesProvider);
    final allCols = List.of(svc.columns)..sort((a, b) => a.position.compareTo(b.position));
    final hidden = ref.watch(columnVisibilityProvider);
    final cols = allCols.where((c) => !hidden.contains(c.id)).toList();
    final tasks = List.of(svc.tasks)..sort((a, b) => a.position.compareTo(b.position));
    final date = ref.watch(selectedDateProvider);
    return Container(
      color: AppColors.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            color: AppColors.header,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Text('Today', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              Text('${date.month}/${date.day}/${date.year}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
                style: IconButton.styleFrom(backgroundColor: AppColors.inputFill, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border))),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2035));
                  if (d != null) ref.read(selectedDateProvider.notifier).state = d;
                },
              )
            ]),
          ),
          const Divider(height: 1, color: AppColors.border),
          for (final t in tasks)
            Card(
              color: AppColors.surface,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    Builder(builder: (_) {
                      final e = svc.entryFor(t.id, date);
                      final checked = e?.checked ?? false;
                      return Checkbox(value: checked, onChanged: (v) => svc.toggleChecked(t.id, date, v ?? false));
                    }),
                    Expanded(child: Text(t.name.isEmpty ? 'Untitled' : t.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                  ]),
                  const Divider(color: AppColors.border, height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final col in cols)
                        SizedBox(
                          width: double.infinity,
                          child: Row(children: [
                            SizedBox(width: 80, child: Text(col.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                            Expanded(
                              child: Builder(builder: (_) {
                                final e = svc.entryFor(t.id, date);
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
                                    return Align(alignment: Alignment.centerLeft, child: Checkbox(value: raw == true, onChanged: (v) => svc.setCellValue(t.id, date, col.id, v)));
                                  case ColumnType.tags:
                                    final ids = raw is List ? List<String>.from(raw) : <String>[];
                                    return TagCell(selectedIds: ids, options: col.tagOptions, onChanged: (v) => svc.setCellValue(t.id, date, col.id, v));
                                  default:
                                    return Text(raw?.toString() ?? '—', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary));
                                }
                              }),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Android simplified view — checkbox + status editing only. Structural edits (add/reorder columns) on Web. Synced via Supabase realtime. Offline queue enabled.',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
