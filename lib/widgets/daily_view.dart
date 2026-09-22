import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/app_providers.dart';
import '../providers/display_prefs.dart';
import '../providers/task_filters.dart';
import '../providers/column_visibility.dart';
import '../utils/date_utils.dart';
import '../models/enums.dart';
import '../models/column_definition.dart';
import 'cells/cell_widgets.dart';
import 'cells/timer_cell.dart';

class DailyView extends ConsumerStatefulWidget {
  const DailyView({super.key});
  @override
  ConsumerState<DailyView> createState() => _DailyViewState();
}

class _DailyViewState extends ConsumerState<DailyView> {
  int _rowPage = 0;
  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(supabaseServiceProvider);
    ref.watch(tasksProvider);
    ref.watch(columnsProvider);
    ref.watch(entriesProvider);
    final allTasks = List.of(svc.tasks)..sort((a, b) => a.position.compareTo(b.position));
    final allCols = List.of(svc.columns)..sort((a, b) => a.position.compareTo(b.position));
    final hidden = ref.watch(columnVisibilityProvider);
    final cols = allCols.where((c) => !hidden.contains(c.id)).toList();
    final date = ref.watch(selectedDateProvider);
    // Daily now filters like Monthly: only tasks scheduled (checkbox checked) for this day
    final scheduledRaw = allTasks.where((t) => (svc.entryFor(t.id, date)?.checked ?? false)).toList();
    final filters = ref.watch(taskFiltersProvider);
    final scheduledTasks = scheduledRaw.where((t) {
      if (filters.search.isNotEmpty && !t.name.toLowerCase().contains(filters.search.toLowerCase())) return false;
      final e = svc.entryFor(t.id, date);
      if (filters.status != null) {
        final statusCol = allCols.where((c) => c.type == ColumnType.status).firstOrNull;
        if (statusCol == null) return false;
        if ((e?.data[statusCol.id] as String?) != filters.status) return false;
      }
      if (filters.hasNoteOnly) {
        final noteCol = allCols.where((c) => c.id == 'col_note').firstOrNull ?? allCols.where((c) => c.type == ColumnType.text && c.label.toLowerCase().contains('note')).firstOrNull;
        if (noteCol == null) return false;
        final note = e?.data[noteCol.id] as String?;
        if (note == null || note.trim().isEmpty) return false;
      }
      if (filters.tag != null) {
        final hasTag = e?.data.values.any((v) => v is List && (v as List).contains(filters.tag)) ?? false;
        if (!hasTag) return false;
      }
      return true;
    }).toList();
    final prefs = ref.watch(displayPrefsProvider);
    final rowsVisible = prefs.rowsVisible;
    final rowPages = rowsVisible == 0 ? 1 : (scheduledTasks.length / rowsVisible).ceil();
    if (_rowPage >= rowPages) _rowPage = rowPages - 1;
    if (_rowPage < 0) _rowPage = 0;
    final tasks = rowsVisible == 0 ? scheduledTasks : scheduledTasks.skip(_rowPage * rowsVisible).take(rowsVisible).toList();

    return Container(
      color: AppColors.bg,
      child: Column(children: [
        Container(
          color: AppColors.header,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary), onPressed: () => ref.read(selectedDateProvider.notifier).state = date.subtract(const Duration(days: 1))),
            Text(formatDayHeader(date), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            Text(formatWeekday(date), style: const TextStyle(color: AppColors.textSecondary)),
            IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary), onPressed: () => ref.read(selectedDateProvider.notifier).state = date.add(const Duration(days: 1))),
            const Spacer(),
            OutlinedButton(onPressed: () => ref.read(selectedDateProvider.notifier).state = DateTime.now(), child: const Text('Today')),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.event_busy, size: 32, color: AppColors.textSecondary),
                    const SizedBox(height: 8),
                    const Text('No tasks scheduled for this day.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('Go to Weekly view and check the box for tasks you want on this date.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('${scheduledTasks.length} of ${allTasks.length} tasks scheduled for ${formatWeekday(date)} ${formatDayHeader(date)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final t = tasks[i];
                    final e = svc.entryFor(t.id, date);
                    final checked = e?.checked ?? false;
                    return Card(
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
                      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Checkbox(value: checked, onChanged: (v) => svc.toggleChecked(t.id, date, v ?? false)),
                          Expanded(child: Text(t.name.isEmpty ? 'Untitled' : t.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                          PopupMenuButton(color: AppColors.surface, icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary), onSelected: (v) {
                            if (v == 'rename') {
                              final c = TextEditingController(text: t.name);
                              showDialog(context: context, builder: (_) => AlertDialog(backgroundColor: AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)), title: const Text('Rename', style: TextStyle(color: AppColors.textPrimary)), content: TextField(controller: c, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(border: OutlineInputBorder())), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { svc.updateTask(t.copyWith(name: c.text)); Navigator.pop(context); }, child: const Text('Save'))]));
                            }
                            if (v == 'delete') svc.deleteTask(t.id);
                          }, itemBuilder: (_) => const [PopupMenuItem(value: 'rename', child: Text('Rename')), PopupMenuItem(value: 'delete', child: Text('Delete'))])
                        ]),
                        const Divider(color: AppColors.border, height: 16),
                        Wrap(spacing: 12, runSpacing: 12, children: [
                          for (final col in cols.where((c) => c.id != 'col_note' && !(c.type == ColumnType.text && c.label.toLowerCase() == 'note')))
                            SizedBox(width: 200, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(col.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                              const SizedBox(height: 6),
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
                                    return InkWell(borderRadius: BorderRadius.circular(8), onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) svc.setCellValue(t.id, date, col.id, d.toIso8601String().split('T').first); }, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)), child: Text(raw ?? 'pick date', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))));
                                  case ColumnType.datetime:
                                    return InkWell(borderRadius: BorderRadius.circular(8), onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null && context.mounted) { final tp = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (tp != null) svc.setCellValue(t.id, date, col.id, DateTime(d.year, d.month, d.day, tp.hour, tp.minute).toIso8601String()); } }, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)), child: Text(raw ?? 'pick datetime', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))));
                                }
                              })
                            ])),
                        ]),
                        // Dedicated note section — every task has a note
                        Builder(builder: (_) {
                          final noteCol = cols.where((c) => c.id == 'col_note').firstOrNull ?? cols.where((c) => c.type == ColumnType.text && c.label.toLowerCase().contains('note')).firstOrNull;
                          if (noteCol == null) return const SizedBox.shrink();
                          final noteVal = e?.valueFor(noteCol.id) as String? ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Divider(color: AppColors.border, height: 1),
                              const SizedBox(height: 8),
                              const Row(children: [Icon(Icons.notes_rounded, size: 12, color: AppColors.textSecondary), SizedBox(width: 6), Text('Note', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4))]),
                              const SizedBox(height: 6),
                              TextFormField(
                                initialValue: noteVal,
                                maxLines: 3,
                                minLines: 2,
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Add a note for this task…',
                                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                onChanged: (v) => svc.setCellValue(t.id, date, noteCol.id, v.isEmpty ? null : v),
                              ),
                            ]),
                          );
                        })
                      ])),
                    );
                  },
                ),
        ),
        if (rowsVisible != 0 && rowPages > 1)
          Container(
            color: AppColors.header,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Text('Rows ${_rowPage * rowsVisible + 1}–${(_rowPage * rowsVisible + tasks.length).clamp(0, scheduledTasks.length)} of ${scheduledTasks.length} scheduled', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const Spacer(),
              OutlinedButton(onPressed: _rowPage > 0 ? () => setState(() => _rowPage--) : null, child: const Text('Prev')),
              const SizedBox(width: 8),
              FilledButton(onPressed: _rowPage < rowPages - 1 ? () => setState(() => _rowPage++) : null, child: const Text('Next')),
            ]),
          ),
      ]),
    );
  }
}
