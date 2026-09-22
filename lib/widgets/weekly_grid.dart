import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/app_providers.dart';
import '../providers/display_prefs.dart';
import '../providers/task_filters.dart';
import '../providers/column_visibility.dart';
import '../models/task.dart';
import '../models/column_definition.dart';
import '../models/enums.dart';
import '../utils/date_utils.dart';
import 'cells/cell_widgets.dart';
import 'cells/timer_cell.dart';

class WeeklyGrid extends ConsumerStatefulWidget {
  const WeeklyGrid({super.key});
  @override
  ConsumerState<WeeklyGrid> createState() => _WeeklyGridState();
}

class _WeeklyGridState extends ConsumerState<WeeklyGrid> {
  final _hHeaderCtrl = ScrollController();
  final _hBodyCtrl = ScrollController();
  final _vCtrl = ScrollController();
  bool _hScrolled = false;
  int _dayPage = 0;
  int _rowPage = 0;

  @override
  void initState() {
    super.initState();
    _hHeaderCtrl.addListener(_onHScroll);
    _hBodyCtrl.addListener(_onHBodyScroll);
  }

  void _onHScroll() {
    if (_hBodyCtrl.hasClients && (_hBodyCtrl.offset - _hHeaderCtrl.offset).abs() > 0.5) {
      _hBodyCtrl.jumpTo(_hHeaderCtrl.offset);
    }
    final scrolled = _hHeaderCtrl.offset > 2 || (_hBodyCtrl.hasClients && _hBodyCtrl.offset > 2);
    if (scrolled != _hScrolled) setState(() => _hScrolled = scrolled);
  }

  void _onHBodyScroll() {
    if (_hHeaderCtrl.hasClients && (_hHeaderCtrl.offset - _hBodyCtrl.offset).abs() > 0.5) {
      _hHeaderCtrl.jumpTo(_hBodyCtrl.offset);
    }
    final scrolled = _hBodyCtrl.offset > 2 || (_hHeaderCtrl.hasClients && _hHeaderCtrl.offset > 2);
    if (scrolled != _hScrolled) setState(() => _hScrolled = scrolled);
  }

  @override
  void dispose() {
    _hHeaderCtrl.dispose();
    _hBodyCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(supabaseServiceProvider);
    ref.watch(tasksProvider);
    ref.watch(columnsProvider);
    ref.watch(entriesProvider);
    final allCols = List.of(svc.columns)..sort((a, b) => a.position.compareTo(b.position));
    final hidden = ref.watch(columnVisibilityProvider);
    final cols = allCols.where((c) => !hidden.contains(c.id)).toList();
    final anchor = ref.watch(selectedDateProvider);
    final allDays = weekDates(anchor);
    final prefs = ref.watch(displayPrefsProvider);
    final filters = ref.watch(taskFiltersProvider);
    final allTasksRaw = List.of(svc.tasks)..sort((a, b) => a.position.compareTo(b.position));
    final allTasks = _applyFilters(allTasksRaw, svc, allCols, filters);

    final daysVisible = prefs.daysVisible == 0 ? allDays.length : prefs.daysVisible;
    final dayPages = (allDays.length / daysVisible).ceil();
    if (_dayPage >= dayPages) _dayPage = dayPages - 1;
    if (_dayPage < 0) _dayPage = 0;
    final days = allDays.skip(_dayPage * daysVisible).take(daysVisible).toList();

    final rowsVisible = prefs.rowsVisible;
    final rowPages = rowsVisible == 0 ? 1 : (allTasks.length / rowsVisible).ceil();
    if (_rowPage >= rowPages) _rowPage = rowPages - 1;
    if (_rowPage < 0) _rowPage = 0;
    final tasks = rowsVisible == 0 ? allTasks : allTasks.skip(_rowPage * rowsVisible).take(rowsVisible).toList();

    return Container(
      color: AppColors.bg,
      child: Column(children: [
        Container(
          color: AppColors.header,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary), onPressed: () => ref.read(selectedDateProvider.notifier).state = anchor.subtract(const Duration(days: 7))),
            Text('${formatShort(allDays.first)} – ${formatShort(allDays.last)} ${allDays.first.year}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 13)),
            IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary), onPressed: () => ref.read(selectedDateProvider.notifier).state = anchor.add(const Duration(days: 7))),
            const Spacer(),
            if (daysVisible < allDays.length) ...[
              IconButton(icon: const Icon(Icons.chevron_left, size: 18), tooltip: 'Prev days', onPressed: _dayPage > 0 ? () => setState(() => _dayPage--) : null),
              Text('${_dayPage + 1}/$dayPages', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              IconButton(icon: const Icon(Icons.chevron_right, size: 18), tooltip: 'Next days', onPressed: _dayPage < dayPages - 1 ? () => setState(() => _dayPage++) : null),
              const SizedBox(width: 4),
            ],
            OutlinedButton(onPressed: () => ref.read(selectedDateProvider.notifier).state = DateTime.now(), child: const Text('Today')),
            const SizedBox(width: 8),
            FilledButton.icon(onPressed: () => _addTaskDialog(context), icon: const Icon(Icons.add, size: 16), label: const Text('Add task')),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(child: _buildStickyGrid(context, tasks, allTasks, cols, days, rowsVisible, _rowPage)),
        if (rowsVisible != 0 && rowPages > 1)
          Container(
            color: AppColors.header,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              Text('Rows ${_rowPage * rowsVisible + 1}–${(_rowPage * rowsVisible + tasks.length).clamp(0, allTasks.length)} of ${allTasks.length}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const Spacer(),
              OutlinedButton(onPressed: _rowPage > 0 ? () => setState(() => _rowPage--) : null, child: const Text('Prev')),
              const SizedBox(width: 8),
              FilledButton(onPressed: _rowPage < rowPages - 1 ? () => setState(() => _rowPage++) : null, child: const Text('Next')),
            ]),
          ),
      ]),
    );
  }

  Widget _buildStickyGrid(BuildContext context, List tasks, List allTasks, List<ColumnDefinition> cols, List<DateTime> days, int rowsVisible, int rowPage) {
    const taskColWidth = 160.0;
    const checkboxWidth = 48.0;
    const colWidth = 132.0;
    final rightWidth = days.length * (checkboxWidth + cols.length * colWidth);
    final totalTableWidth = taskColWidth + rightWidth;
    final screenWidth = MediaQuery.of(context).size.width;
    final shouldCenter = totalTableWidth < screenWidth - 32;

    Widget headerDays = SizedBox(
      width: rightWidth,
      height: 64,
      child: Row(children: [
        for (final d in days)
          SizedBox(
            width: checkboxWidth + cols.length * colWidth,
            child: Column(children: [
              Container(height: 28, color: AppColors.header, alignment: Alignment.center, child: Text(formatWeekday(d), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 0.6))),
              SizedBox(height: 36, child: Row(children: [
                SizedBox(width: checkboxWidth, child: Center(child: Text(formatDayHeader(d), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)))),
                for (final col in cols) SizedBox(width: colWidth, child: Center(child: Text(col.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)))),
              ])),
            ]),
          ),
      ]),
    );

    // header row: use Expanded for scrollable when not centered, SizedBox when centered
    Widget headerRowScrollable = Row(children: [
      Container(
        width: taskColWidth,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.header,
          border: const Border(right: BorderSide(color: AppColors.border)),
          boxShadow: _hScrolled ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(2, 0))] : null,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: const Text('Tasks', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 12, letterSpacing: 0.4)),
      ),
      Expanded(child: SingleChildScrollView(controller: _hHeaderCtrl, scrollDirection: Axis.horizontal, physics: const ClampingScrollPhysics(), child: headerDays)),
    ]);

    Widget headerRowFixed = Row(children: [
      Container(
        width: taskColWidth,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.header,
          border: const Border(right: BorderSide(color: AppColors.border)),
          boxShadow: _hScrolled ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(2, 0))] : null,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: const Text('Tasks', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 12, letterSpacing: 0.4)),
      ),
      SizedBox(width: rightWidth, height: 64, child: SingleChildScrollView(controller: _hHeaderCtrl, scrollDirection: Axis.horizontal, physics: const ClampingScrollPhysics(), child: headerDays)),
    ]);

    final header = Container(
      decoration: BoxDecoration(
        color: AppColors.header,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: shouldCenter ? Center(child: SizedBox(width: totalTableWidth, child: headerRowFixed)) : headerRowScrollable,
    );

    Widget leftColumn = ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      onReorder: (o, n) => _handleReorder(o, n, allTasks, rowsVisible, rowPage),
      itemBuilder: (ctx, i) => _LeftTaskCell(key: ValueKey(tasks[i].id), task: tasks[i], index: i, isAlt: i % 2 == 1, hScrolled: _hScrolled, onRename: () => _renameTask(context, tasks[i])),
    );

    Widget rightColumn = Column(children: [
      for (int r = 0; r < tasks.length; r++)
        _RightTaskRow(task: tasks[r], days: days, cols: cols, isAlt: r % 2 == 1),
    ]);

    Widget bodyRowScrollable = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: taskColWidth, child: leftColumn),
        Expanded(child: SingleChildScrollView(controller: _hBodyCtrl, scrollDirection: Axis.horizontal, physics: const ClampingScrollPhysics(), child: SizedBox(width: rightWidth, child: rightColumn))),
      ],
    );

    Widget bodyRowFixed = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: taskColWidth, child: leftColumn),
        SizedBox(width: rightWidth, child: SingleChildScrollView(controller: _hBodyCtrl, scrollDirection: Axis.horizontal, physics: const ClampingScrollPhysics(), child: SizedBox(width: rightWidth, child: rightColumn))),
      ],
    );

    final bodyContent = shouldCenter ? Center(child: SizedBox(width: totalTableWidth, child: bodyRowFixed)) : bodyRowScrollable;

    final body = Expanded(
      child: Scrollbar(
        controller: _vCtrl,
        child: SingleChildScrollView(
          controller: _vCtrl,
          child: bodyContent,
        ),
      ),
    );

    final tipContent = Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)), borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        dense: true,
        title: Text('Showing ${tasks.length} of ${allTasks.length} tasks${days.length == 7 ? '' : ' · ${days.length} of 7 days visible'} — adjust in view settings (tune icon). The Tasks column stays fixed while you scroll horizontally.',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        trailing: IconButton(icon: const Icon(Icons.add, color: AppColors.accent), onPressed: () => _addTaskDialog(context)),
      ),
    );
    final tip = shouldCenter ? Center(child: SizedBox(width: totalTableWidth, child: tipContent)) : tipContent;

    return Column(children: [
      header,
      body,
      tip,
    ]);
  }

  Future<void> _handleReorder(int oldIdx, int newIdx, List allTasks, int rowsVisible, int rowPage) async {
    final svc = ref.read(supabaseServiceProvider);
    int actualOld = oldIdx;
    int actualNew = newIdx;
    if (rowsVisible != 0) {
      final base = rowPage * rowsVisible;
      actualOld = base + oldIdx;
      actualNew = base + newIdx;
      if (actualNew > actualOld) actualNew -= 1;
      actualOld = actualOld.clamp(0, allTasks.length - 1);
      actualNew = actualNew.clamp(0, allTasks.length);
    }
    final sorted = List.of(svc.tasks)..sort((a, b) => a.position.compareTo(b.position));
    final filteredIds = allTasks.map((t) => (t as Task).id).toList();
    if (filteredIds.length == sorted.length) {
      await svc.reorderTasks(actualOld, actualNew);
    } else {
      if (actualOld < filteredIds.length && actualNew < filteredIds.length) {
        final oldId = filteredIds[actualOld];
        final newId = filteredIds[actualNew > actualOld ? actualNew - 1 : actualNew];
        final oldPos = sorted.indexWhere((t) => t.id == oldId);
        final newPos = sorted.indexWhere((t) => t.id == newId);
        if (oldPos != -1 && newPos != -1) await svc.reorderTasks(oldPos, newPos > oldPos ? newPos + 1 : newPos);
      }
    }
  }

  List<Task> _applyFilters(List<Task> tasks, svc, List<ColumnDefinition> cols, TaskFilters f) {
    if (f.search.isEmpty && f.status == null && !f.hasNoteOnly && f.tag == null) return tasks;
    final statusCol = cols.where((c) => c.type == ColumnType.status).firstOrNull;
    final noteCol = cols.where((c) => c.id == 'col_note').firstOrNull ?? cols.where((c) => c.type == ColumnType.text && c.label.toLowerCase().contains('note')).firstOrNull;
    return tasks.where((t) {
      if (f.search.isNotEmpty && !t.name.toLowerCase().contains(f.search.toLowerCase())) return false;
      if (f.hasNoteOnly) {
        if (noteCol == null) return false;
        final hasNote = svc.entries.any((e) => e.taskId == t.id && (e.data[noteCol.id] as String?)?.trim().isNotEmpty == true);
        if (!hasNote) return false;
      }
      if (f.status != null) {
        if (statusCol == null) return false;
        final hasStatus = svc.entries.any((e) => e.taskId == t.id && e.data[statusCol.id] == f.status);
        if (!hasStatus) return false;
      }
      if (f.tag != null) {
        final hasTag = svc.entries.any((e) => e.taskId == t.id && e.data.values.any((v) => v is List && (v as List).contains(f.tag)));
        if (!hasTag) return false;
      }
      return true;
    }).toList();
  }

  void _addTaskDialog(BuildContext context) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
        title: const Text('Add task', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(controller: c, autofocus: true, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Task name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () { final svc = ref.read(supabaseServiceProvider); if (c.text.trim().isNotEmpty) svc.addTask(c.text.trim()); Navigator.pop(context); }, child: const Text('Add')),
        ],
      ),
    );
  }

  void _renameTask(BuildContext context, dynamic task) {
    final c = TextEditingController(text: task.name);
    showDialog(context: context, builder: (_) => AlertDialog(backgroundColor: AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)), title: const Text('Rename task', style: TextStyle(color: AppColors.textPrimary)), content: TextField(controller: c, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(border: OutlineInputBorder())), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { ref.read(supabaseServiceProvider).updateTask(task.copyWith(name: c.text)); Navigator.pop(context); }, child: const Text('Save'))]));
  }
}

class _LeftTaskCell extends ConsumerWidget {
  final dynamic task;
  final int index;
  final bool isAlt;
  final bool hScrolled;
  final VoidCallback onRename;
  const _LeftTaskCell({super.key, required this.task, required this.index, required this.isAlt, required this.hScrolled, required this.onRename});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.read(supabaseServiceProvider);
    final rowBg = isAlt ? AppColors.surfaceAlt : AppColors.surface;
    return Container(
      key: ValueKey('left-${task.id}'),
      height: 48,
      decoration: BoxDecoration(
        color: rowBg,
        border: const Border(bottom: BorderSide(color: AppColors.border, width: 1), right: BorderSide(color: AppColors.border)),
        boxShadow: hScrolled ? [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 6, offset: const Offset(2, 0))] : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle, size: 14, color: AppColors.textSecondary)),
        const SizedBox(width: 6),
        Expanded(child: InkWell(onTap: onRename, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(task.name.isEmpty ? '—' : task.name, style: TextStyle(fontSize: 12, color: task.name.isEmpty ? AppColors.textSecondary : AppColors.textPrimary, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)))),
        PopupMenuButton(color: AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)), itemBuilder: (_) => const [PopupMenuItem(value: 'rename', child: Text('Rename')), PopupMenuItem(value: 'delete', child: Text('Delete'))], onSelected: (v) { if (v == 'rename') onRename(); if (v == 'delete') svc.deleteTask(task.id); }, icon: const Icon(Icons.more_horiz, size: 16, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _RightTaskRow extends ConsumerWidget {
  final dynamic task;
  final List<DateTime> days;
  final List<ColumnDefinition> cols;
  final bool isAlt;
  const _RightTaskRow({required this.task, required this.days, required this.cols, required this.isAlt});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(supabaseServiceProvider);
    final rowBg = isAlt ? AppColors.surfaceAlt : AppColors.surface;
    return Container(
      height: 48,
      decoration: BoxDecoration(color: rowBg, border: const Border(bottom: BorderSide(color: AppColors.border, width: 1))),
      child: Row(children: [
        for (final d in days) ...[
          Container(width: 48, height: 48, alignment: Alignment.center, decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.border))), child: Builder(builder: (_) { final e = svc.entryFor(task.id, d); final checked = e?.checked ?? false; return Checkbox(value: checked, onChanged: (v) => svc.toggleChecked(task.id, d, v ?? false), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap); })),
          for (final col in cols) Container(width: 132, height: 48, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.border))), alignment: Alignment.center, child: _Cell(taskId: task.id, date: d, col: col)),
        ],
      ]),
    );
  }
}

class _Cell extends ConsumerWidget {
  final String taskId;
  final DateTime date;
  final ColumnDefinition col;
  const _Cell({required this.taskId, required this.date, required this.col});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(supabaseServiceProvider);
    final e = svc.entryFor(taskId, date);
    final raw = e?.valueFor(col.id);
    switch (col.type) {
      case ColumnType.checkbox:
        return Checkbox(value: raw == true, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v), visualDensity: VisualDensity.compact);
      case ColumnType.schedule:
        return ScheduleCell(value: raw as String?, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v));
      case ColumnType.status:
        return StatusCell(valueId: raw as String?, options: col.statusOptions, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v));
      case ColumnType.number:
        return DurationCell(value: raw as String?, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v));
      case ColumnType.text:
        return DurationCell(value: raw as String?, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v));
      case ColumnType.timer:
        return TimerCell(taskId: taskId, date: date, columnId: col.id, rawValue: raw);
      case ColumnType.date:
        return InkWell(borderRadius: BorderRadius.circular(8), onTap: () async { final d = await showDatePicker(context: context, initialDate: raw != null ? DateTime.tryParse(raw) ?? DateTime.now() : DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) svc.setCellValue(taskId, date, col.id, d.toIso8601String().split('T').first); }, child: Container(height: 32, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)), child: Text(raw ?? '—', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))));
      case ColumnType.datetime:
        return InkWell(borderRadius: BorderRadius.circular(8), onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null && context.mounted) { final t = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (t != null) { final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute); svc.setCellValue(taskId, date, col.id, dt.toIso8601String()); } } }, child: Container(height: 32, padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)), child: Text(raw != null ? raw.toString().substring(0, 16) : '—', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))));
      case ColumnType.tags:
        final ids = raw is List ? List<String>.from(raw) : <String>[];
        return TagCell(selectedIds: ids, options: col.tagOptions, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v));
    }
  }
}
