import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../providers/app_providers.dart';
import '../providers/display_prefs.dart';
import '../services/supabase_service.dart';
import 'monthly_view.dart';
import '../providers/task_filters.dart';
import '../providers/column_visibility.dart';
import '../models/task.dart';
import '../models/column_definition.dart';
import '../models/enums.dart';
import '../utils/date_utils.dart';
import 'cells/cell_widgets.dart';
import 'cells/compact_cell.dart';
import 'cells/reminder_cell.dart';
import 'cells/timer_cell.dart';
import 'monthly_view.dart';
import 'note_editor_panel.dart';
import 'reminder_dialog.dart';

class WeeklyGrid extends ConsumerStatefulWidget {
  const WeeklyGrid({super.key});
  @override
  ConsumerState<WeeklyGrid> createState() => _WeeklyGridState();
}

class _WeeklyGridState extends ConsumerState<WeeklyGrid> {
  final _hHeaderCtrl = ScrollController();
  final _hBodyCtrl = ScrollController();
  final _vCtrl = ScrollController();
  final _vRightCtrl = ScrollController();
  bool _hScrolled = false;
  int _dayPage = 0;
  int _rowPage = 0;
  String? _flashDayKey; // dateKey of the day column to flash-highlight
  Timer? _flashTimer;
  String? _hoverTaskId; // task id of the hovered row (shared by both halves)

  void _setHover(String? id) {
    if (_hoverTaskId != id) setState(() => _hoverTaskId = id);
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Jump to the current week, scroll today's column into view and flash it.
  void _goToday() {
    final now = DateTime.now();
    final todayNorm = normalizeDate(now);
    ref.read(selectedDateProvider.notifier).state = now;
    // Ensure the day-page containing today is shown.
    final prefs = ref.read(displayPrefsProvider);
    final allDays = weekDates(now);
    final daysVisible = prefs.daysVisible == 0 ? allDays.length : prefs.daysVisible;
    final todayIdx = allDays.indexWhere((d) => normalizeDate(d) == todayNorm);
    setState(() {
      _dayPage = todayIdx >= 0 ? todayIdx ~/ daysVisible : 0;
      _flashDayKey = _dateKey(todayNorm);
    });
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _flashDayKey = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToDayColumn(todayNorm));
  }

  /// Horizontally scroll today's day-column into the center of the viewport.
  void _scrollToDayColumn(DateTime todayNorm) {
    if (!_hBodyCtrl.hasClients) return;
    final svc = ref.read(supabaseServiceProvider);
    final hidden = ref.read(columnVisibilityProvider);
    final cols = svc.columns.where((c) => !hidden.contains(c.id)).toList();
    final basic = ref.read(displayPrefsProvider).basicCells;
    const checkboxWidth = 48.0;
    const fullColWidth = 132.0;
    const basicColWidth = 76.0;
    final dayWidth = checkboxWidth +
        cols.fold(0.0, (s, c) => s + ((basic && (c.type == ColumnType.timer || c.type == ColumnType.status)) ? basicColWidth : fullColWidth));
    final anchor = ref.read(selectedDateProvider);
    final prefs = ref.read(displayPrefsProvider);
    final allDays = weekDates(anchor);
    final daysVisible = prefs.daysVisible == 0 ? allDays.length : prefs.daysVisible;
    final dayPages = (allDays.length / daysVisible).ceil();
    final page = _dayPage.clamp(0, dayPages - 1);
    final days = allDays.skip(page * daysVisible).take(daysVisible).toList();
    final ti = days.indexWhere((d) => normalizeDate(d) == todayNorm);
    if (ti < 0) return;
    final pos = _hBodyCtrl.position;
    if (pos.maxScrollExtent <= 0) return;
    final target = (ti * dayWidth + dayWidth / 2 - pos.viewportDimension / 2).clamp(0.0, pos.maxScrollExtent);
    _hBodyCtrl.animateTo(target, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
  }

  @override
  void initState() {
    super.initState();
    _hHeaderCtrl.addListener(_onHScroll);
    _hBodyCtrl.addListener(_onHBodyScroll);
    // The reorderable task column owns vertical scrolling; the data side
    // mirrors it so rows always line up (and dragging never fights a
    // parent scroll view).
    _vCtrl.addListener(_syncRightV);
  }

  void _syncRightV() {
    if (!_vRightCtrl.hasClients || !_vCtrl.hasClients) return;
    final max = _vRightCtrl.position.maxScrollExtent;
    final target = _vCtrl.offset.clamp(0.0, max);
    if ((_vRightCtrl.offset - target).abs() > 0.5) {
      _vRightCtrl.jumpTo(target);
    }
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
    _flashTimer?.cancel();
    _hHeaderCtrl.dispose();
    _hBodyCtrl.dispose();
    _vCtrl.dispose();
    _vRightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(supabaseServiceProvider);
    ref.watch(tasksProvider);
    ref.watch(columnsProvider);
    ref.watch(entriesProvider);
    final t = AppLocalizations.of(context)!;
    final narrow = MediaQuery.of(context).size.width < 560;
    final allCols = List.of(svc.columns)..sort((a, b) => a.position.compareTo(b.position));
    final hidden = ref.watch(columnVisibilityProvider);
    final cols = allCols.where((c) => !hidden.contains(c.id)).toList();
    final anchor = ref.watch(selectedDateProvider);
    final allDays = weekDates(anchor);
    final prefs = ref.watch(displayPrefsProvider);
    final filters = ref.watch(taskFiltersProvider);
    final allTasksRaw = List.of(svc.tasks)..sort((a, b) => a.position.compareTo(b.position));
    // Day order: tasks scheduled (checked) for the selected day come first,
    // unscheduled ones after — no manual dragging needed.
    final allTasks = _applyFilters(allTasksRaw, svc, allCols, filters)
      ..sort((a, b) {
        final ea = svc.entryFor(a.id, anchor)?.checked ?? false;
        final eb = svc.entryFor(b.id, anchor)?.checked ?? false;
        if (ea != eb) return ea ? -1 : 1;
        return a.position.compareTo(b.position);
      });

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
          padding: EdgeInsets.symmetric(horizontal: narrow ? 6 : 12, vertical: 8),
          child: Row(children: [
            IconButton(icon: Icon(Icons.chevron_left, color: AppColors.textSecondary), onPressed: () => ref.read(selectedDateProvider.notifier).state = anchor.subtract(Duration(days: 7))),
            Flexible(
              child: Text('${formatShort(allDays.first)} – ${formatShort(allDays.last)} ${allDays.first.year}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: narrow ? 11 : 13), overflow: TextOverflow.ellipsis),
            ),
            IconButton(icon: Icon(Icons.chevron_right, color: AppColors.textSecondary), onPressed: () => ref.read(selectedDateProvider.notifier).state = anchor.add(Duration(days: 7))),
            if (!narrow) const Spacer(),
            if (daysVisible < allDays.length) ...[
              IconButton(icon: const Icon(Icons.chevron_left, size: 18), tooltip: t.prevDaysTip, onPressed: _dayPage > 0 ? () => setState(() => _dayPage--) : null),
              Text('${_dayPage + 1}/$dayPages', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              IconButton(icon: const Icon(Icons.chevron_right, size: 18), tooltip: t.nextDaysTip, onPressed: _dayPage < dayPages - 1 ? () => setState(() => _dayPage++) : null),
              const SizedBox(width: 4),
            ],
            OutlinedButton(onPressed: _goToday, child: Text(t.today)),
            const SizedBox(width: 8),
            narrow
                ? IconButton.filled(onPressed: () => _addTaskDialog(context), icon: Icon(Icons.add, size: 18), tooltip: t.addTask)
                : FilledButton.icon(onPressed: () => _addTaskDialog(context), icon: Icon(Icons.add, size: 16), label: Text(t.addTask)),
          ]),
        ),
        Divider(height: 1, color: AppColors.border),
        Expanded(child: _buildStickyGrid(context, tasks, allTasks, cols, days, rowsVisible, _rowPage)),
        if (rowsVisible != 0 && rowPages > 1)
          Container(
            color: AppColors.header,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              Text(t.rowsRange('${_rowPage * rowsVisible + 1}', '${(_rowPage * rowsVisible + tasks.length).clamp(0, allTasks.length)}', '${allTasks.length}'), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const Spacer(),
              OutlinedButton(onPressed: _rowPage > 0 ? () => setState(() => _rowPage--) : null, child: Text(t.prevBtn)),
              const SizedBox(width: 8),
              FilledButton(onPressed: _rowPage < rowPages - 1 ? () => setState(() => _rowPage++) : null, child: Text(t.nextBtn)),
            ]),
          ),
      ]),
    );
  }

  Widget _buildStickyGrid(BuildContext context, List tasks, List allTasks, List<ColumnDefinition> cols, List<DateTime> days, int rowsVisible, int rowPage) {
    final loc = AppLocalizations.of(context)!;
    const taskColWidth = 160.0;
    const checkboxWidth = 48.0;
    const fullColWidth = 132.0;
    const basicColWidth = 76.0;
    final basic = ref.watch(displayPrefsProvider).basicCells;
    // In Basic mode timer/status cells are icon-only, so they get narrow columns.
    double widthFor(ColumnDefinition col) =>
        (basic && (col.type == ColumnType.timer || col.type == ColumnType.status)) ? basicColWidth : fullColWidth;
    final dayWidth = checkboxWidth + cols.fold(0.0, (s, c) => s + widthFor(c));
    final rightWidth = days.length * dayWidth;
    final totalTableWidth = taskColWidth + rightWidth;
    final screenWidth = MediaQuery.of(context).size.width;
    final shouldCenter = totalTableWidth < screenWidth - 32;

    Widget headerDays = SizedBox(
      width: rightWidth,
      height: 64,
      child: Row(children: [
        for (final d in days)
          Builder(builder: (_) {
            final flash = _flashDayKey != null && _dateKey(d) == _flashDayKey;
            return Tooltip(
              message: loc.openDaily(formatDayHeader(d)),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                // Tapping a day header jumps straight to that day in Daily view.
                onTap: () {
                  ref.read(selectedDateProvider.notifier).state = d;
                  ref.read(viewModeProvider.notifier).state = ViewMode.daily;
                },
                child: Container(
              width: dayWidth,
              decoration: flash
                  ? BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
                    )
                  : null,
              child: Column(children: [
              Container(height: 28, color: AppColors.header, alignment: Alignment.center, child: Text(formatWeekday(d), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 0.6))),
              SizedBox(height: 36, child: Row(children: [
                SizedBox(
                  width: checkboxWidth,
                  child: Center(
                    // Shrink the date to fit instead of wrapping to a second
                    // line (which overflowed the fixed 64px header by ~2px).
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(formatDayHeader(d), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary), maxLines: 1),
                    ),
                  ),
                ),
                for (final col in cols) SizedBox(width: widthFor(col), child: Center(child: Text(col.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis))),
              ])),
            ]),
                ),
              ),
            );
          }),
      ]),
    );

    // header row: use Expanded for scrollable when not centered, SizedBox when centered
    Widget headerRowScrollable = Row(children: [
      Container(
        width: taskColWidth,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.header,
          border: Border(right: BorderSide(color: AppColors.border)),
          boxShadow: _hScrolled ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(2, 0))] : null,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(loc.tasksHeader, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 12, letterSpacing: 0.4)),
      ),
      Expanded(child: SingleChildScrollView(controller: _hHeaderCtrl, scrollDirection: Axis.horizontal, physics: const ClampingScrollPhysics(), child: headerDays)),
    ]);

    Widget headerRowFixed = Row(children: [
      Container(
        width: taskColWidth,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.header,
          border: Border(right: BorderSide(color: AppColors.border)),
          boxShadow: _hScrolled ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(2, 0))] : null,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(loc.tasksHeader, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 12, letterSpacing: 0.4)),
      ),
      SizedBox(width: rightWidth, height: 64, child: SingleChildScrollView(controller: _hHeaderCtrl, scrollDirection: Axis.horizontal, physics: const ClampingScrollPhysics(), child: headerDays)),
    ]);

    final header = Container(
      decoration: BoxDecoration(
        color: AppColors.header,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: shouldCenter ? Center(child: SizedBox(width: totalTableWidth, child: headerRowFixed)) : headerRowScrollable,
    );

    // The task column IS the vertical scroller. Rows auto-sort with the
    // selected day's scheduled (checked) tasks first — no manual dragging.
    Widget leftColumn = ListView.builder(
      controller: _vCtrl,
      padding: EdgeInsets.zero,
      itemCount: tasks.length,
      itemBuilder: (ctx, i) => _LeftTaskCell(
          key: ValueKey(tasks[i].id),
          task: tasks[i],
          isAlt: i % 2 == 1,
          hScrolled: _hScrolled,
          hovered: _hoverTaskId == (tasks[i] as Task).id,
          onHover: (h) => _setHover(h ? (tasks[i] as Task).id : null),
          onRename: () => _renameTask(context, tasks[i]),
          onNotesRecap: () => _showNotesRecap(context, tasks[i])),
    );

    Widget rightColumn = Column(children: [
      for (int r = 0; r < tasks.length; r++)
        _RightTaskRow(
          task: tasks[r],
          days: days,
          cols: cols,
          isAlt: r % 2 == 1,
          flashDayKey: _flashDayKey,
          basic: basic,
          hovered: _hoverTaskId == (tasks[r] as Task).id,
          onHover: (h) => _setHover(h ? (tasks[r] as Task).id : null),
        ),
    ]);

    Widget rightSide = SingleChildScrollView(
      controller: _vRightCtrl,
      physics: const NeverScrollableScrollPhysics(),
      child: Scrollbar(
        controller: _hBodyCtrl,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: SingleChildScrollView(
            controller: _hBodyCtrl,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(width: rightWidth, child: rightColumn)),
      ),
    );

    Widget bodyRowScrollable = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: taskColWidth, child: Scrollbar(controller: _vCtrl, child: leftColumn)),
        Expanded(child: rightSide),
      ],
    );

    Widget bodyRowFixed = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: taskColWidth, child: Scrollbar(controller: _vCtrl, child: leftColumn)),
        SizedBox(width: rightWidth, child: rightSide),
      ],
    );

    final bodyContent = shouldCenter ? Center(child: SizedBox(width: totalTableWidth, child: bodyRowFixed)) : bodyRowScrollable;

    final body = Expanded(child: bodyContent);

    final tipContent = Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)), borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true,
        title: Text(loc.showingTip('${tasks.length}', '${allTasks.length}', days.length == 7 ? '' : loc.daysVisiblePart('${days.length}', '7')),
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        trailing: IconButton(icon: Icon(Icons.add, color: AppColors.accent), onPressed: () => _addTaskDialog(context)),
      ),
    );
    final tip = shouldCenter ? Center(child: SizedBox(width: totalTableWidth, child: tipContent)) : tipContent;

    return Column(children: [
      header,
      body,
      tip,
    ]);
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
    // Full create sheet: name (only required field) + optional days and params.
    showAddTaskDialog(context, multiDate: true, initialDate: ref.read(selectedDateProvider));
  }

  void _renameTask(BuildContext context, dynamic task) {
    final loc = AppLocalizations.of(context)!;
    final c = TextEditingController(text: task.name);
    showDialog(context: context, builder: (_) => AlertDialog(backgroundColor: AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)), title: Text(loc.rename, style: TextStyle(color: AppColors.textPrimary)), content: TextField(controller: c, style: TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(border: OutlineInputBorder())), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.cancel)), FilledButton(onPressed: () { ref.read(supabaseServiceProvider).updateTask(task.copyWith(name: c.text)); Navigator.pop(context); }, child: Text(loc.save))]));
  }

  ColumnDefinition? _resolveNoteCol(List<ColumnDefinition> cols) {
    return cols.where((c) => c.id == 'col_note').firstOrNull ??
        cols.where((c) => c.type == ColumnType.text && c.label.toLowerCase().contains('note')).firstOrNull;
  }

  /// Notes recap: every dated note for one task in a single dialog.
  /// Notes are editable inline — save writes back to that day's cell.
  void _showNotesRecap(BuildContext context, Task task) {
    final loc = AppLocalizations.of(context)!;
    final svc = ref.read(supabaseServiceProvider);
    final allCols = List.of(svc.columns)..sort((a, b) => a.position.compareTo(b.position));
    final noteCol = _resolveNoteCol(allCols);
    final name = task.name.isEmpty ? loc.untitledCap : task.name;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.border)),
        title: Row(children: [
          Icon(Icons.notes_rounded, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(loc.recapTitle(name), style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis)),
        ]),
        content: SizedBox(width: 400, child: _NotesRecapList(task: task, noteCol: noteCol)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.close))],
      ),
    );
  }
}

class _LeftTaskCell extends ConsumerStatefulWidget {
  final dynamic task;
  final bool isAlt;
  final bool hScrolled;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final VoidCallback onRename;
  final VoidCallback onNotesRecap;
  const _LeftTaskCell({super.key, required this.task, required this.isAlt, required this.hScrolled, required this.hovered, required this.onHover, required this.onRename, required this.onNotesRecap});
  @override
  ConsumerState<_LeftTaskCell> createState() => _LeftTaskCellState();
}

class _LeftTaskCellState extends ConsumerState<_LeftTaskCell> {
  @override
  Widget build(BuildContext context) {
    final svc = ref.read(supabaseServiceProvider);
    final loc = AppLocalizations.of(context)!;
    final task = widget.task;
    final hovered = widget.hovered;
    final rowBg = widget.isAlt ? AppColors.surfaceAlt : AppColors.surface;
    final bg = hovered ? Color.alphaBlend(AppColors.accent.withValues(alpha: 0.12), rowBg) : rowBg;
    final hoverSide = BorderSide(color: AppColors.accent, width: 1.5);
    // Note count for the menu label.
    final allCols = List.of(svc.columns)..sort((a, b) => a.position.compareTo(b.position));
    final noteCol = allCols.where((c) => c.id == 'col_note').firstOrNull ??
        allCols.where((c) => c.type == ColumnType.text && c.label.toLowerCase().contains('note')).firstOrNull;
    int noteCount = 0;
    if (noteCol != null) {
      noteCount = svc.entries.where((e) => e.taskId == task.id && notePlainText(e.data[noteCol.id]).isNotEmpty).length;
    }
    return MouseRegion(
      onEnter: (_) => widget.onHover(true),
      onExit: (_) => widget.onHover(false),
      child: Container(
        key: ValueKey('left-${task.id}'),
        height: 48,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            bottom: hovered ? hoverSide : BorderSide(color: AppColors.border, width: 1),
            right: hovered ? hoverSide : BorderSide(color: AppColors.border),
            top: hovered ? hoverSide : BorderSide.none,
            left: hovered ? hoverSide : BorderSide.none,
          ),
          boxShadow: widget.hScrolled ? [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 6, offset: const Offset(2, 0))] : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          Expanded(child: InkWell(onTap: widget.onRename, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(task.name.isEmpty ? '—' : task.name, style: TextStyle(fontSize: 12, color: task.name.isEmpty ? AppColors.textSecondary : AppColors.textPrimary, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)))),
          if ((task.reminder as String?)?.isNotEmpty == true)
            Tooltip(
              message: loc.bellTip((task.reminder as String).toUpperCase()),
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(Icons.notifications_outlined, size: 13, color: AppColors.accent),
              ),
            ),
          PopupMenuButton(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'notes', child: Text(noteCol == null ? loc.notesRecap : loc.notesRecapCount('$noteCount'))),
              PopupMenuItem(
                  value: 'reminder',
                  child: Text((task.reminder as String?)?.isNotEmpty == true ? loc.reminderSet((task.reminder as String).toUpperCase()) : loc.setReminderItem)),
              PopupMenuItem(value: 'rename', child: Text(loc.rename)),
              PopupMenuItem(value: 'delete', child: Text(loc.delete)),
            ],
            onSelected: (v) {
              if (v == 'notes') widget.onNotesRecap();
              if (v == 'reminder') showReminderDialog(context, task as Task);
              if (v == 'rename') widget.onRename();
              if (v == 'delete') svc.deleteTask(task.id);
            },
            icon: Icon(Icons.more_horiz, size: 16, color: AppColors.textSecondary),
          ),
        ]),
      ),
    );
  }
}

class _RightTaskRow extends ConsumerStatefulWidget {
  final dynamic task;
  final List<DateTime> days;
  final List<ColumnDefinition> cols;
  final bool isAlt;
  final String? flashDayKey;
  final bool basic;
  final bool hovered;
  final ValueChanged<bool> onHover;
  const _RightTaskRow({required this.task, required this.days, required this.cols, required this.isAlt, this.flashDayKey, required this.basic, required this.hovered, required this.onHover});
  @override
  ConsumerState<_RightTaskRow> createState() => _RightTaskRowState();
}

class _RightTaskRowState extends ConsumerState<_RightTaskRow> {
  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  double _widthFor(ColumnDefinition col) =>
      (widget.basic && (col.type == ColumnType.timer || col.type == ColumnType.status)) ? 76.0 : 132.0;
  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(supabaseServiceProvider);
    final task = widget.task;
    final days = widget.days;
    final cols = widget.cols;
    final hovered = widget.hovered;
    final rowBg = widget.isAlt ? AppColors.surfaceAlt : AppColors.surface;
    final bg = hovered ? Color.alphaBlend(AppColors.accent.withValues(alpha: 0.12), rowBg) : rowBg;
    final hoverSide = BorderSide(color: AppColors.accent, width: 1.5);
    return MouseRegion(
      onEnter: (_) => widget.onHover(true),
      onExit: (_) => widget.onHover(false),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            bottom: hovered ? hoverSide : BorderSide(color: AppColors.border, width: 1),
            top: hovered ? hoverSide : BorderSide.none,
            right: hovered ? hoverSide : BorderSide.none,
          ),
        ),
        child: Row(children: [
          for (final d in days) ...[
            Builder(builder: (_) {
              final flash = widget.flashDayKey != null && _dateKey(d) == widget.flashDayKey;
              final flashBg = flash ? AppColors.accent.withValues(alpha: 0.12) : null;
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: flashBg, border: Border(left: BorderSide(color: AppColors.border))), child: Builder(builder: (_) { final e = svc.entryFor(task.id, d); final checked = e?.checked ?? false; return Checkbox(value: checked, onChanged: (v) => svc.toggleChecked(task.id, d, v ?? false), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap); })),
                for (final col in cols) Container(width: _widthFor(col), height: 48, padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), decoration: BoxDecoration(color: flashBg, border: Border(left: BorderSide(color: AppColors.border))), alignment: Alignment.center, child: _Cell(taskId: task.id, date: d, col: col)),
              ]);
            }),
          ],
        ]),
      ),
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
    final basic = ref.watch(displayPrefsProvider).basicCells;
    final loc = AppLocalizations.of(context)!;
    final e = svc.entryFor(taskId, date);
    final raw = e?.valueFor(col.id);
    switch (col.type) {
      case ColumnType.checkbox:
        return Checkbox(value: raw == true, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v), visualDensity: VisualDensity.compact);
      case ColumnType.schedule:
        return ScheduleCell(value: raw as String?, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v));
      case ColumnType.status:
        if (basic) {
          return CompactStatusIcon(taskId: taskId, date: date, col: col, rawValue: raw, title: loc.editColLabel(col.label));
        }
        return StatusCell(valueId: raw as String?, options: col.statusOptions, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v));
      case ColumnType.number:
        return DurationCell(value: raw as String?, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v));
      case ColumnType.text:
        // Notes open the full sidebar studio; other text edits inline.
        if (isNoteColumn(col)) {
          return OpenNotesCell(taskId: taskId, date: date, col: col, rawValue: raw);
        }
        return DurationCell(value: raw as String?, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v));
      case ColumnType.timer:
        if (basic) {
          return CompactTimerIcon(taskId: taskId, date: date, columnId: col.id, rawValue: raw, title: loc.editColLabel(col.label));
        }
        return TimerCell(taskId: taskId, date: date, columnId: col.id, rawValue: raw);
      case ColumnType.reminder:
        return ReminderCell(taskId: taskId, date: date, columnId: col.id, rawValue: raw);
      case ColumnType.date:
        return InkWell(borderRadius: BorderRadius.circular(8), onTap: () async { final d = await showDatePicker(context: context, initialDate: raw != null ? DateTime.tryParse(raw) ?? DateTime.now() : DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) svc.setCellValue(taskId, date, col.id, d.toIso8601String().split('T').first); }, child: Container(height: 32, alignment: Alignment.centerLeft, padding: EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)), child: Text(raw ?? '—', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))));
      case ColumnType.datetime:
        return InkWell(borderRadius: BorderRadius.circular(8), onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null && context.mounted) { final t = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (t != null) { final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute); svc.setCellValue(taskId, date, col.id, dt.toIso8601String()); } } }, child: Container(height: 32, padding: EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)), child: Text(raw != null ? raw.toString().substring(0, 16) : '—', style: TextStyle(fontSize: 10, color: AppColors.textSecondary))));
      case ColumnType.tags:
        final ids = raw is List ? List<String>.from(raw) : <String>[];
        return TagCell(selectedIds: ids, options: col.tagOptions, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v));
    }
  }
}

/// Notes recap list: tap any note to open it in the sidebar studio.
/// Delete clears that day's note. List updates live from the cloud.
class _NotesRecapList extends ConsumerWidget {
  final Task task;
  final ColumnDefinition? noteCol;
  const _NotesRecapList({required this.task, required this.noteCol});

  List<MapEntry<DateTime, String>> _notes(SupabaseService svc) {
    final col = noteCol;
    if (col == null) return [];
    final out = <MapEntry<DateTime, String>>[];
    for (final e in svc.entries.where((e) => e.taskId == task.id)) {
      final v = notePlainText(e.data[col.id]);
      if (v.isNotEmpty) out.add(MapEntry(e.date, v));
    }
    out.sort((a, b) => a.key.compareTo(b.key));
    return out;
  }

  void _openInSidebar(BuildContext context, WidgetRef ref, DateTime date) {
    Navigator.of(context).pop();
    ref.read(noteEditorRequestProvider.notifier).state =
        NoteEditorRequest(taskId: task.id, date: date, columnId: noteCol!.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(supabaseServiceProvider);
    final loc = AppLocalizations.of(context)!;
    final col = noteCol;
    final name = task.name.isEmpty ? loc.untitledCap : task.name;
    if (col == null) {
      return Text(loc.noNoteCol, style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
    }
    final notes = _notes(svc);
    if (notes.isEmpty) {
      return Text(loc.noNotesYet(name, col.label), style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
    }
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final n in notes)
            Builder(builder: (_) {
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openInSidebar(context, ref, n.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
                        child: Text('${n.key.month}/${n.key.day}/${n.key.year}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)),
                      ),
                      const Spacer(),
                      Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () async => svc.setCellValue(task.id, n.key, col.id, null),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Tooltip(message: loc.deleteTip, child: Icon(Icons.delete_outline, size: 14, color: AppColors.textSecondary)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(n.value, style: TextStyle(fontSize: 12, color: AppColors.textPrimary), maxLines: 4, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(loc.tapOpenStudio, style: TextStyle(fontSize: 9, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                  ]),
                ),
              );
            }),
        ],
      ),
    );
  }
}
