import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../config/ui_style.dart';
import '../providers/app_providers.dart';
import '../providers/display_prefs.dart';
import '../providers/task_filters.dart';
import '../providers/column_visibility.dart';
import '../utils/date_utils.dart';
import '../models/enums.dart';
import '../models/column_definition.dart';
import '../models/timer_value.dart';
import 'cells/cell_widgets.dart';
import 'cells/compact_cell.dart';
import 'cells/timer_cell.dart';
import 'note_editor_panel.dart';

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

    // --- stats for this day ---
    final loc = AppLocalizations.of(context)!;
    final statusCol = allCols.where((c) => c.type == ColumnType.status).firstOrNull;
    final timeCol = allCols.where((c) => c.type == ColumnType.timer).firstOrNull;
    int total = scheduledRaw.length;
    int done = 0;
    int inProgress = 0;
    int totalSec = 0;
    int doneSec = 0;
    int elapsedSec = 0;
    int remainingSec = 0;
    List<String> doneNames = [];
    List<String> todoNames = [];
    for (final tq in scheduledRaw) {
      final e = svc.entryFor(tq.id, date);
      final s = statusCol != null ? e?.data[statusCol.id] as String? : null;
      if (s == 'done') done++;
      if (s == 'in_progress' || s == 'in progress') inProgress++;
      // time
      if (timeCol != null) {
        final raw = e?.data[timeCol.id];
        final tv = TimerValue.tryParse(raw);
        if (tv != null && tv.durationSec > 0) {
          totalSec += tv.durationSec;
          final eff = tv.effectiveElapsed(DateTime.now());
          elapsedSec += eff.clamp(0, tv.durationSec);
          if (s == 'done') {
            doneSec += tv.durationSec;
            remainingSec += 0;
          } else {
            doneSec += 0;
            remainingSec += (tv.durationSec - eff).clamp(0, tv.durationSec);
          }
        }
      }
      if (s == 'done') doneNames.add(tq.name.isEmpty ? loc.untitledCap : tq.name);
      else todoNames.add(tq.name.isEmpty ? loc.untitledCap : tq.name);
    }
    final pct = total == 0 ? 0.0 : done / total;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 600 ? 1 : width < 900 ? 2 : width < 1300 ? 3 : 4;
    final dayLabel = '${formatWeekday(date)} ${formatDayHeader(date)}';

    return Container(
      color: AppColors.bg,
      child: Column(children: [
        Container(
          color: AppColors.header,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            IconButton(icon: Icon(Icons.chevron_left, color: AppColors.textSecondary), onPressed: () => ref.read(selectedDateProvider.notifier).state = date.subtract(Duration(days: 1))),
            Text(formatDayHeader(date), style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            Text(formatWeekday(date), style: TextStyle(color: AppColors.textSecondary)),
            IconButton(icon: Icon(Icons.chevron_right, color: AppColors.textSecondary), onPressed: () => ref.read(selectedDateProvider.notifier).state = date.add(Duration(days: 1))),
            const Spacer(),
            OutlinedButton(onPressed: () => ref.read(selectedDateProvider.notifier).state = DateTime.now(), child: Text(loc.today)),
          ]),
        ),
        Divider(height: 1, color: AppColors.border),
        // Stats panel
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.insights_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(loc.statsFor(dayLabel), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: pct >= 1 ? AppColors.doneFill : AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: pct >= 1 ? AppColors.doneBorder : AppColors.border)),
                child: Text(loc.pctDone((pct * 100).toStringAsFixed(0)), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: pct >= 1 ? AppColors.doneText : AppColors.textSecondary)),
              ),
            ]),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: AppColors.inputFill, valueColor: AlwaysStoppedAnimation(pct >= 1 ? const Color(0xFF22C55E) : AppColors.accent), borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _statChip(Icons.list_alt_rounded, loc.totalChip, loc.tasksCount('$total'), AppColors.textPrimary),
              _statChip(Icons.check_circle_rounded, loc.doneChip, '$done', const Color(0xFF22C55E)),
              _statChip(Icons.timelapse_rounded, loc.progChip, '$inProgress', const Color(0xFFF59E0B)),
              _statChip(Icons.schedule_rounded, loc.totalTimeChip, TimerValue.formatSec(totalSec), AppColors.accent),
              _statChip(Icons.hourglass_bottom_rounded, loc.doneTimeChip, TimerValue.formatSec(doneSec), const Color(0xFF22C55E)),
              _statChip(Icons.hourglass_empty_rounded, loc.leftChip, TimerValue.formatSec(remainingSec), const Color(0xFFF43F5E)),
              _statChip(Icons.timelapse_rounded, loc.elapsedChip, TimerValue.formatSec(elapsedSec), AppColors.textSecondary),
            ]),
            if (doneNames.isNotEmpty || todoNames.isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Icon(Icons.check, size: 12, color: Color(0xFF22C55E)), SizedBox(width: 4), Text(loc.doneSection, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF22C55E)))]),
                    const SizedBox(height: 4),
                    Text(doneNames.isEmpty ? '—' : doneNames.take(5).join(', ') + (doneNames.length > 5 ? ' ${loc.moreSuffix('${doneNames.length - 5}')}' : ''), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Icon(Icons.pending_rounded, size: 12, color: AppColors.textSecondary), SizedBox(width: 4), Text(loc.leftToDo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))]),
                    const SizedBox(height: 4),
                    Text(todoNames.isEmpty ? '—' : todoNames.take(5).join(', ') + (todoNames.length > 5 ? ' ${loc.moreSuffix('${todoNames.length - 5}')}' : ''), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                ),
              ]),
            ],
          ]),
        ),
        Divider(height: 1, color: AppColors.border),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.event_busy, size: 32, color: AppColors.textSecondary),
                    const SizedBox(height: 8),
                    Text(loc.noScheduled, style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(loc.goWeeklyHint, style: TextStyle(color: AppColors.textSecondary, fontSize: 11), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(loc.scheduledLine('${scheduledTasks.length}', '${allTasks.length}', dayLabel), style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                  ]),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: tasks.length,
                  itemBuilder: (_, i) {
                    final t = tasks[i];
                    final e = svc.entryFor(t.id, date);
                    final checked = e?.checked ?? false;
                    return _SquareTaskCard(task: t, date: date, checked: checked, cols: cols, entry: e);
                  },
                ),
        ),
        if (rowsVisible != 0 && rowPages > 1)
          Container(
            color: AppColors.header,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Text('Rows ${_rowPage * rowsVisible + 1}–${(_rowPage * rowsVisible + tasks.length).clamp(0, scheduledTasks.length)} of ${scheduledTasks.length} scheduled', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const Spacer(),
              OutlinedButton(onPressed: _rowPage > 0 ? () => setState(() => _rowPage--) : null, child: const Text('Prev')),
              const SizedBox(width: 8),
              FilledButton(onPressed: _rowPage < rowPages - 1 ? () => setState(() => _rowPage++) : null, child: const Text('Next')),
            ]),
          ),
      ]),
    );
  }

  Widget _statChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text('$label: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _SquareTaskCard extends ConsumerWidget {
  final dynamic task;
  final DateTime date;
  final bool checked;
  final List<ColumnDefinition> cols;
  final dynamic entry;
  const _SquareTaskCard({required this.task, required this.date, required this.checked, required this.cols, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(supabaseServiceProvider);
    final basic = ref.watch(displayPrefsProvider).basicCells;
    final loc = AppLocalizations.of(context)!;
    final statusCol = cols.where((c) => c.type == ColumnType.status).firstOrNull;
    final statusVal = statusCol != null ? entry?.data[statusCol.id] as String? : null;
    Color borderColor = AppColors.border;
    if (statusVal == 'done') borderColor = const Color(0xFF22C55E).withValues(alpha: 0.6);
    else if (statusVal == 'in_progress' || statusVal == 'in progress') borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.6);
    else if (statusVal == 'cancel') borderColor = const Color(0xFFF43F5E).withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 2)), ...UiStyle.neuCard()],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: AppColors.header, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            Checkbox(value: checked, onChanged: (v) => svc.toggleChecked(task.id, date, v ?? false), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            const SizedBox(width: 4),
            Expanded(child: Text(task.name.isEmpty ? loc.untitledCap : task.name, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 13), overflow: TextOverflow.ellipsis)),
            PopupMenuButton(
              color: AppColors.surface,
              icon: Icon(Icons.more_horiz, size: 16, color: AppColors.textSecondary),
              onSelected: (v) {
                if (v == 'rename') {
                  final c = TextEditingController(text: task.name);
                  showDialog(context: context, builder: (_) => AlertDialog(backgroundColor: AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)), title: Text(loc.rename, style: TextStyle(color: AppColors.textPrimary)), content: TextField(controller: c, style: TextStyle(color: AppColors.textPrimary), decoration: InputDecoration(border: OutlineInputBorder())), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.cancel)), FilledButton(onPressed: () { svc.updateTask(task.copyWith(name: c.text)); Navigator.pop(context); }, child: Text(loc.save))]));
                }
                if (v == 'delete') svc.deleteTask(task.id);
              },
              itemBuilder: (_) => [PopupMenuItem(value: 'rename', child: Text(loc.rename)), PopupMenuItem(value: 'delete', child: Text(loc.delete))],
            ),
          ]),
        ),
        Divider(height: 1, color: AppColors.border),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols.length == 1 ? 1 : 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: cols.length == 1 ? 4 : 3.2),
                  itemCount: cols.length,
                  itemBuilder: (_, idx) {
                    final col = cols[idx];
                    final raw = entry?.data[col.id];
                    Widget child;
                    switch (col.type) {
                      case ColumnType.schedule:
                        child = ScheduleCell(value: raw as String?, onChanged: (v) => svc.setCellValue(task.id, date, col.id, v));
                        break;
                      case ColumnType.status:
                        child = basic
                            ? CompactStatusIcon(taskId: task.id, date: date, col: col, rawValue: raw, title: loc.editColLabel(col.label))
                            : StatusCell(valueId: raw as String?, options: col.statusOptions, onChanged: (v) => svc.setCellValue(task.id, date, col.id, v));
                        break;
                      case ColumnType.number:
                        child = DurationCell(value: raw as String?, onChanged: (v) => svc.setCellValue(task.id, date, col.id, v));
                        break;
                      case ColumnType.text:
                        // Notes open the full sidebar studio; other text edits inline.
                        child = isNoteColumn(col)
                            ? OpenNotesCell(taskId: task.id, date: date, col: col, rawValue: raw)
                            : DurationCell(value: raw as String?, onChanged: (v) => svc.setCellValue(task.id, date, col.id, v));
                        break;
                      case ColumnType.timer:
                        child = basic
                            ? CompactTimerIcon(taskId: task.id, date: date, columnId: col.id, rawValue: raw, title: loc.editColLabel(col.label))
                            : TimerCell(taskId: task.id, date: date, columnId: col.id, rawValue: raw);
                        break;
                      case ColumnType.checkbox:
                        child = Align(alignment: Alignment.centerLeft, child: Checkbox(value: raw == true, onChanged: (v) => svc.setCellValue(task.id, date, col.id, v), visualDensity: VisualDensity.compact));
                        break;
                      case ColumnType.tags:
                        final ids = raw is List ? List<String>.from(raw) : <String>[];
                        child = TagCell(selectedIds: ids, options: col.tagOptions, onChanged: (v) => svc.setCellValue(task.id, date, col.id, v));
                        break;
                      case ColumnType.date:
                        child = InkWell(borderRadius: BorderRadius.circular(8), onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) svc.setCellValue(task.id, date, col.id, d.toIso8601String().split('T').first); }, child: Container(padding: EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)), child: Text(raw ?? '—', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))));
                        break;
                      case ColumnType.datetime:
                        child = InkWell(borderRadius: BorderRadius.circular(8), onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null && context.mounted) { final tp = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (tp != null) svc.setCellValue(task.id, date, col.id, DateTime(d.year, d.month, d.day, tp.hour, tp.minute).toIso8601String()); } }, child: Container(padding: EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)), child: Text(raw != null ? raw.toString().substring(0, 16) : '—', style: TextStyle(fontSize: 10, color: AppColors.textSecondary))));
                    }
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(col.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3)),
                      const SizedBox(height: 4),
                      Expanded(child: child),
                    ]);
                  },
                ),
              ),
              // note preview at bottom of square
              Builder(builder: (_) {
                final noteCol = cols.where((c) => c.id == 'col_note').firstOrNull ?? cols.where((c) => c.type == ColumnType.text && c.label.toLowerCase().contains('note')).firstOrNull;
                if (noteCol == null) return const SizedBox.shrink();
                final noteVal = entry?.data[noteCol.id] as String? ?? '';
                if (noteVal.trim().isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Icon(Icons.notes_rounded, size: 10, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(child: Text(noteVal, style: TextStyle(fontSize: 10, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                );
              }),
            ]),
          ),
        ),
      ]),
    );
  }
}
