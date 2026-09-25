import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../providers/app_providers.dart';
import '../providers/column_visibility.dart';
import '../providers/task_filters.dart';
import '../models/enums.dart';
import 'cells/cell_widgets.dart';
import 'cells/compact_cell.dart';
import 'cells/reminder_cell.dart';
import 'cells/timer_cell.dart';

class AndroidChecklist extends ConsumerWidget {
  const AndroidChecklist({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(supabaseServiceProvider);
    ref.watch(tasksProvider);
    ref.watch(columnsProvider);
    ref.watch(entriesProvider);
    final loc = AppLocalizations.of(context)!;
    final filters = ref.watch(taskFiltersProvider);
    final allCols = List.of(svc.columns)..sort((a, b) => a.position.compareTo(b.position));
    final hidden = ref.watch(columnVisibilityProvider);
    final cols = allCols.where((c) => !hidden.contains(c.id)).toList();
    final allTasks = List.of(svc.tasks)..sort((a, b) => a.position.compareTo(b.position));
    // Apply same filters as web (search/status/tag/hasNote) for phone
    final tasks = allTasks.where((t) {
      if (filters.search.isNotEmpty && !t.name.toLowerCase().contains(filters.search.toLowerCase())) return false;
      if (filters.status != null) {
        final statusCol = allCols.where((c) => c.type == ColumnType.status).firstOrNull;
        if (statusCol == null) return false;
        final hasStatus = svc.entries.any((e) => e.taskId == t.id && e.data[statusCol.id] == filters.status);
        if (!hasStatus) return false;
      }
      if (filters.hasNoteOnly) {
        final noteCol = allCols.where((c) => c.id == 'col_note').firstOrNull;
        if (noteCol == null) return false;
        final hasNote = svc.entries.any((e) => e.taskId == t.id && (e.data[noteCol.id] as String?)?.trim().isNotEmpty == true);
        if (!hasNote) return false;
      }
      if (filters.tag != null) {
        final hasTag = svc.entries.any((e) => e.taskId == t.id && e.data.values.any((v) => v is List && (v as List).contains(filters.tag)));
        if (!hasTag) return false;
      }
      return true;
    }).toList();
    final date = ref.watch(selectedDateProvider);
    // Day order: assigned (non-idle status) tasks first, the rest after.
    tasks.sort((a, b) {
      final ea = svc.entryFor(a.id, date);
      final eb = svc.entryFor(b.id, date);
      final aa = ea != null && svc.isAssigned(ea);
      final bb = eb != null && svc.isAssigned(eb);
      if (aa != bb) return aa ? -1 : 1;
      return a.position.compareTo(b.position);
    });
    final isSmall = MediaQuery.of(context).size.width < 380;
    return Container(
      color: AppColors.bg,
      child: ListView(
        padding: EdgeInsets.only(bottom: 24, left: isSmall ? 8 : 0, right: isSmall ? 8 : 0),
        children: [
          Container(
            color: AppColors.header,
            padding: EdgeInsets.all(isSmall ? 12 : 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.checklist_rounded, size: 20, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(loc.todayTitle, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
                const Spacer(),
                Text('${date.month}/${date.day}/${date.year}', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
                  style: IconButton.styleFrom(backgroundColor: AppColors.inputFill, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border))),
                  onPressed: () async {
                    final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (d != null) ref.read(selectedDateProvider.notifier).state = d;
                  },
                )
              ]),
              const SizedBox(height: 12),
              // Search for phone - compact
              TextField(
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: loc.searchHint,
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                ),
                onChanged: (v) => ref.read(taskFiltersProvider.notifier).setSearch(v),
              ),
              if (tasks.length != allTasks.length) ...[
                const SizedBox(height: 8),
                Text(loc.tapFilterHint('${tasks.length}', '${allTasks.length}'), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ]),
          ),
          Divider(height: 1, color: AppColors.border),
          for (final t in tasks)
            Card(
              color: AppColors.surface,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    Builder(builder: (_) {
                      final statusCol = allCols.where((c) => c.type == ColumnType.status).firstOrNull;
                      final e = svc.entryFor(t.id, date);
                      if (statusCol == null) {
                        final checked = e?.checked ?? false;
                        return Checkbox(value: checked, onChanged: (v) => svc.toggleChecked(t.id, date, v ?? false));
                      }
                      return StatusDotButton(taskId: t.id, date: date, col: statusCol, rawValue: e?.data[statusCol.id], title: loc.editColLabel(statusCol.label));
                    }),
                    const SizedBox(width: 6),
                    Expanded(child: Text(t.name.isEmpty ? loc.untitledCap : t.name, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                  ]),
                  Divider(color: AppColors.border, height: 16),
                  // Responsive: on small phones, stack more compact
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final col in cols)
                        SizedBox(
                          width: double.infinity,
                          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                            SizedBox(width: isSmall ? 68 : 80, child: Text(col.label, style: TextStyle(fontSize: isSmall ? 11 : 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
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
                                  case ColumnType.reminder:
                                    return ReminderCell(taskId: t.id, date: date, columnId: col.id, rawValue: raw);
                                  case ColumnType.checkbox:
                                    return Align(alignment: Alignment.centerLeft, child: Checkbox(value: raw == true, onChanged: (v) => svc.setCellValue(t.id, date, col.id, v)));
                                  case ColumnType.tags:
                                    final ids = raw is List ? List<String>.from(raw) : <String>[];
                                    return TagCell(selectedIds: ids, options: col.tagOptions, onChanged: (v) => svc.setCellValue(t.id, date, col.id, v));
                                  default:
                                    return Text(raw?.toString() ?? '—', style: TextStyle(fontSize: 12, color: AppColors.textPrimary));
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
            child: Text(loc.androidNote,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
