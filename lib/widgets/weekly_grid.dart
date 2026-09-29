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
import 'day_detail_panel.dart';
import '../models/task.dart';
import '../models/column_definition.dart';
import '../models/enums.dart';
import '../utils/date_utils.dart';
import 'cells/cell_widgets.dart';
import 'cells/compact_cell.dart';
import 'cells/reminder_cell.dart';
import 'cells/timer_cell.dart';
import 'task_pool.dart';
import 'monthly_view.dart';
import 'note_editor_panel.dart';
import 'reminder_dialog.dart';

/// Space between one date's block of cells and the next, in the same spirit as
/// the gap between the cards in Daily view. A gap replaced the vertical rule:
/// empty space separates the days without drawing a line through them, and the
/// row behind the gap is the page colour, so the gap actually reads as one.
double _dayGapFor(bool mobile) => mobile ? 5.0 : 9.0;

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
  bool _pool = false; // mind-map pool layout instead of the table

  void _setHover(String? id) {
    if (_hoverTaskId != id) setState(() => _hoverTaskId = id);
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// The 48px schedule-toggle column is only needed when the workspace has
  /// no visible status column (status values assign days on their own).
  bool _needsToggle(List<ColumnDefinition> cols) => !cols.any((c) => c.type == ColumnType.status);

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
    const fullColWidth = 132.0;
    const basicColWidth = 76.0;
    final toggleW = _needsToggle(cols) ? 48.0 : 0.0;
    final dayWidth = toggleW +
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
    // Day order: tasks assigned (non-idle status) for the selected day first.
    final allTasks = _applyFilters(allTasksRaw, svc, allCols, filters)
      ..sort((a, b) {
        final ea = svc.entryFor(a.id, anchor);
        final eb = svc.entryFor(b.id, anchor);
        final aa = ea != null && svc.isAssigned(ea);
        final bb = eb != null && svc.isAssigned(eb);
        if (aa != bb) return aa ? -1 : 1;
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

    // On a phone the weekly grid is replaced by a plain list of every task,
    // scheduled or not: a 7-day spreadsheet cannot be read at 400px, and the
    // only thing a phone needs from "weekly" is "what do I have, and when is
    // it happening". Tapping a task opens a sheet to schedule or edit it.
    if (MediaQuery.of(context).size.width < 600) {
      return _buildMobileTaskList(context, svc, allTasks, allCols);
    }

    return Container(
      color: AppColors.bg,
      child: Column(children: [
        Container(
          color: AppColors.header,
          padding: EdgeInsets.symmetric(horizontal: narrow ? 6 : 12, vertical: 8),
          child: Row(children: [
            // A 393px phone cannot fit five 48px icon buttons + Today + the
            // day pager, so on narrow screens every control shrinks to its
            // icon box and the title absorbs what is left.
            IconButton(
              icon: Icon(Icons.chevron_left, color: AppColors.textSecondary),
              style: _iconBtnStyle(narrow),
              onPressed: () => ref.read(selectedDateProvider.notifier).state = anchor.subtract(Duration(days: 7)),
            ),
            Flexible(
              child: Text('${formatShort(allDays.first)} – ${formatShort(allDays.last)} ${allDays.first.year}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: narrow ? 11 : 13), overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right, color: AppColors.textSecondary),
              style: _iconBtnStyle(narrow),
              onPressed: () => ref.read(selectedDateProvider.notifier).state = anchor.add(Duration(days: 7)),
            ),
            if (!narrow) const Spacer(),
            if (daysVisible < allDays.length) ...[
              IconButton(icon: const Icon(Icons.chevron_left, size: 18), tooltip: t.prevDaysTip, style: _iconBtnStyle(narrow), onPressed: _dayPage > 0 ? () => setState(() => _dayPage--) : null),
              Text('${_dayPage + 1}/$dayPages', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              IconButton(icon: const Icon(Icons.chevron_right, size: 18), tooltip: t.nextDaysTip, style: _iconBtnStyle(narrow), onPressed: _dayPage < dayPages - 1 ? () => setState(() => _dayPage++) : null),
              if (!narrow) const SizedBox(width: 4),
            ],
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, narrow ? 30 : 40),
                padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 16),
                textStyle: TextStyle(fontSize: narrow ? 11 : 14),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _goToday,
              child: Text(t.today),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(_pool ? Icons.table_chart_outlined : Icons.account_tree_outlined, color: AppColors.textSecondary),
              tooltip: _pool ? t.tableView : t.poolView,
              style: _iconBtnStyle(narrow),
              onPressed: () => setState(() => _pool = !_pool),
            ),
            narrow
                ? IconButton.filled(
                    style: _iconBtnStyle(narrow, filled: true),
                    onPressed: () => _addTaskDialog(context),
                    icon: Icon(Icons.add, size: 18),
                    tooltip: t.addTask,
                  )
                : FilledButton.icon(onPressed: () => _addTaskDialog(context), icon: Icon(Icons.add, size: 16), label: Text(t.addTask)),
          ]),
        ),
        Divider(height: 1, color: AppColors.border),
        Expanded(child: _pool ? TaskPool(tasks: allTasks, cols: allCols, date: anchor) : _buildStickyGrid(context, tasks, allTasks, cols, days, rowsVisible, _rowPage)),
        if (!_pool && rowsVisible != 0 && rowPages > 1)
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
    final screenWidth = MediaQuery.of(context).size.width;
    // A phone cannot show a 7-day spreadsheet: 160 + 76x7 = 692px of table on a
    // ~420px screen meant 1.5 visible days, clipped names and constant
    // horizontal scrolling. On narrow screens the week collapses to one status
    // dot per day so the whole week fits without scrolling.
    final mobile = screenWidth < 600;
    final veryNarrow = screenWidth < 400;
    final hasStatus = cols.any((c) => c.type == ColumnType.status);
    final visibleCols = mobile
        ? (hasStatus ? cols.where((c) => c.type == ColumnType.status).take(1).toList() : cols.where((c) => c.type == ColumnType.checkbox).take(1).toList())
        : cols;
    final dayColWidth = veryNarrow ? 34.0 : 40.0;
    final taskColWidth = mobile ? (veryNarrow ? 148.0 : 168.0) : 160.0;
    const fullColWidth = 132.0;
    const basicColWidth = 76.0;
    final basic = ref.watch(displayPrefsProvider).basicCells;
    // Schedule-toggle column only when no visible status column assigns days
    // (never on mobile: the day cell itself is the dot/checkbox).
    final toggleW = (!mobile && _needsToggle(cols)) ? 48.0 : 0.0;
    // In Basic mode timer/status cells are icon-only, so they get narrow columns.
    double widthFor(ColumnDefinition col) => mobile
        ? dayColWidth
        : (basic && (col.type == ColumnType.timer || col.type == ColumnType.status)) ? basicColWidth : fullColWidth;
    // The gap belongs to the day block, so it is inside [dayWidth] and cannot
    // push the last day out of the scrollable area.
    final dayGap = _dayGapFor(mobile);
    final dayWidth = toggleW + visibleCols.fold(0.0, (s, c) => s + widthFor(c)) + dayGap;
    // +2px slack so sub-pixel/border accumulation can never trip an overflow.
    final rightWidth = days.length * dayWidth + 2;
    final totalTableWidth = taskColWidth + rightWidth;
    final headerH = mobile ? 44.0 : 64.0;
    final rowH = mobile ? 44.0 : 48.0;
    final shouldCenter = totalTableWidth < screenWidth - 32;

    Widget headerDays = SizedBox(
      width: rightWidth,
      height: headerH,
      child: Row(children: [
        for (int di = 0; di < days.length; di++)
          Builder(builder: (_) {
            final d = days[di];
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
              // Leading gap: the page colour shows through here, which is what
              // separates one date from the next in both header and body.
              padding: EdgeInsets.only(left: dayGap),
              decoration: flash
                  ? BoxDecoration(color: AppColors.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8))
                  : null,
              // Every border goes on `foregroundDecoration`: a `decoration`
              // border pads the child (1px/side for the today outline), which
              // pushed this day to 414x62 and overflowed the 416-wide row.
              // The left hairline separates one date from the next; the flash
              // outline is kept separate because a borderRadius may only be
              // used with a uniform border.
              foregroundDecoration: flash
                  ? BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.accent.withValues(alpha: 0.55)))
                  : null,
              // Phones get one compact line ("21 Mon"); the full date + the
              // column-label row is what forced 132px columns.
              child: mobile
                  ? Container(
                      height: headerH,
                      color: AppColors.header,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${d.day}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1),
                        Text(_cap(_weekdayShort(d)), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textSecondary), maxLines: 1),
                      ]),
                    )
                  : Column(children: [
              Container(
                height: 28,
                color: AppColors.header,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                // Date next to the day: "9/25/2026 Thursday".
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${formatDayHeader(d)} ${_cap(formatWeekday(d))}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 0.4),
                      maxLines: 1),
                ),
              ),
              // Expanded instead of a fixed 36 so the label row absorbs any
              // rounding instead of overflowing the 64px header.
              Expanded(child: Row(children: [
                if (toggleW > 0) const SizedBox(width: 48),
                for (final col in visibleCols) SizedBox(width: widthFor(col), child: Center(child: Text(col.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis))),
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
        height: headerH,
        decoration: BoxDecoration(
          color: AppColors.header,
          border: Border(right: BorderSide(color: AppColors.border)),
          boxShadow: _hScrolled ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(2, 0))] : null,
        ),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: mobile ? 6 : 12),
        child: Text(loc.tasksHeader, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 12, letterSpacing: 0.4)),
      ),
      Expanded(child: SingleChildScrollView(controller: _hHeaderCtrl, scrollDirection: Axis.horizontal, physics: const ClampingScrollPhysics(), child: headerDays)),
    ]);

    Widget headerRowFixed = Row(children: [
      Container(
        width: taskColWidth,
        height: headerH,
        decoration: BoxDecoration(
          color: AppColors.header,
          border: Border(right: BorderSide(color: AppColors.border)),
          boxShadow: _hScrolled ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(2, 0))] : null,
        ),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: mobile ? 6 : 12),
        child: Text(loc.tasksHeader, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 12, letterSpacing: 0.4)),
      ),
      SizedBox(width: rightWidth, height: headerH, child: SingleChildScrollView(controller: _hHeaderCtrl, scrollDirection: Axis.horizontal, physics: const ClampingScrollPhysics(), child: headerDays)),
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
          cols: visibleCols,
          isAlt: r % 2 == 1,
          flashDayKey: _flashDayKey,
          basic: basic,
          mobile: mobile,
          dayColWidth: dayColWidth,
          rowH: rowH,
          showToggle: toggleW > 0,
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

    final body = Expanded(child: RepaintBoundary(child: bodyContent));

    // The tip banner pointed at the desktop tune icon and carried a second
    // add button; on a phone it just ate a strip of screen (the FAB already
    // adds tasks), so it becomes one quiet line.
    final tipContent = mobile
        ? Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Text(
              loc.showingTip('${tasks.length}', '${allTasks.length}', days.length == 7 ? '' : loc.daysVisiblePart('${days.length}', '7')),
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : Container(
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

  /// Phone version of the weekly page: every task in one list, with a small
  /// dot per day of the current week showing where it is scheduled.
  Widget _buildMobileTaskList(BuildContext context, svc, List<Task> tasks, List<ColumnDefinition> allCols) {
    final t = AppLocalizations.of(context)!;
    final days = weekDates(ref.watch(selectedDateProvider));
    final statusCol = allCols.where((c) => c.type == ColumnType.status).firstOrNull;
    if (tasks.isEmpty) {
      return Container(
        color: AppColors.bg,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.checklist_rounded, size: 30, color: AppColors.textSecondary),
            const SizedBox(height: 10),
            Text(t.noTasksYet, style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
    }
    return Container(
      color: AppColors.bg,
      child: Column(children: [
        Container(
          color: AppColors.header,
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(children: [
            Text(t.allTasksLbl, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(999)),
              child: Text('${tasks.length}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.add_rounded, size: 20, color: AppColors.accent),
              tooltip: t.addTask,
              onPressed: () => _addTaskDialog(context),
            ),
          ]),
        ),
        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 90),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
            itemBuilder: (_, i) {
              final task = tasks[i];
              return InkWell(
                onTap: () => _openMobileTaskSheet(context, task, days, statusCol),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        task.name.isEmpty ? t.untitledCap : task.name,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Which days of this week it is on, at a glance.
                    for (final d in days)
                      Builder(builder: (_) {
                        final e = svc.entryFor(task.id, d);
                        final on = e != null && svc.isAssigned(e);
                        return Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: on ? AppColors.accent : AppColors.border,
                          ),
                        );
                      }),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  /// One line describing what is already on this task for this day, so the
  /// sheet can show what the day editor is about to change.
  String _dayCellSummary(SupabaseService svc, Task task, DateTime day) {
    final e = svc.entryFor(task.id, day);
    if (e == null) return '';
    final parts = <String>[];
    for (final c in List.of(svc.columns)) {
      // Status is already shown by the day chip, and free text can be a whole
      // note: neither belongs in a one-line summary.
      if (c.type == ColumnType.status || c.type == ColumnType.text) continue;
      final v = e.valueFor(c.id)?.toString().trim();
      if (v == null || v.isEmpty) continue;
      parts.add(v);
    }
    return parts.join(' · ');
  }

  /// Tap target on the phone list: schedule the task on any day of the week,
  /// or edit / rename / delete / set a reminder.
  Future<void> _openMobileTaskSheet(BuildContext context, Task task, List<DateTime> days, ColumnDefinition? statusCol) async {
    final loc = AppLocalizations.of(context)!;
    final svc = ref.read(supabaseServiceProvider);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          task.name.isEmpty ? loc.untitledCap : task.name,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary), onPressed: () => Navigator.pop(sheetCtx)),
                    ]),
                    const SizedBox(height: 4),
                    Text(loc.tapToSchedule, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in days)
                          Builder(builder: (_) {
                            final e = svc.entryFor(task.id, d);
                            final on = e != null && svc.isAssigned(e);
                            final isToday = _dateKey(d) == _dateKey(DateTime.now());
                            return InkWell(
                              borderRadius: BorderRadius.circular(9),
                              onTap: () {
                                if (statusCol != null) {
                                  // Status drives the assignment: none = on, idle = off.
                                  svc.setCellValue(task.id, d, statusCol.id, on ? 'idle' : 'none');
                                } else {
                                  svc.toggleChecked(task.id, d, !on);
                                }
                                setSheet(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: on ? AppColors.accent : AppColors.inputFill,
                                  borderRadius: BorderRadius.circular(9),
                                  border: isToday ? Border.all(color: AppColors.accent.withValues(alpha: 0.5)) : null,
                                ),
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Text(
                                    '${_weekdayShort(d)} ${d.day}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    on ? loc.doneSection.toLowerCase() : loc.notScheduledShort,
                                    style: TextStyle(fontSize: 9.5, color: on ? Colors.white70 : AppColors.textSecondary),
                                  ),
                                ]),
                              ),
                            );
                          }),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Full editing of the task on a given day. The day chips
                    // above only answer "is it on that day"; the day panel is
                    // where status, schedule, duration and notes are edited.
                    if (days.where((d) {
                          final e = svc.entryFor(task.id, d);
                          return e != null && svc.isAssigned(e);
                        }).isNotEmpty) ...[
                      Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 2),
                        child: Text(loc.editTaskDay, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                      ),
                      for (final d in days)
                        Builder(builder: (_) {
                          final e = svc.entryFor(task.id, d);
                          if (e == null || !svc.isAssigned(e)) return const SizedBox.shrink();
                          final summary = _dayCellSummary(svc, task, d);
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.tune_rounded, size: 18, color: AppColors.textSecondary),
                            title: Text(
                              '${_cap(_weekdayShort(d))} ${d.day}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            subtitle: summary.isEmpty
                                ? null
                                : Text(summary, style: TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              showDayDetail(context, d);
                            },
                          );
                        }),
                    ],
                    const SizedBox(height: 8),
                    Divider(height: 1, color: AppColors.border),
                    Row(children: [
                      TextButton.icon(
                        icon: const Icon(Icons.notifications_outlined, size: 16),
                        label: Text(loc.setReminderItem, style: const TextStyle(fontSize: 12.5)),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          showReminderDialog(context, task);
                        },
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(loc.rename, style: const TextStyle(fontSize: 12.5)),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _renameTask(context, task);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        color: const Color(0xFFF43F5E),
                        tooltip: loc.delete,
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          svc.deleteTask(task.id);
                        },
                      ),
                    ]),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

/// Compact icon-button box for phone toolbars. IconButton defaults to a
/// 40-48px tap target, which is what overflowed the weekly toolbar at 393px.
ButtonStyle _iconBtnStyle(bool narrow, {bool filled = false}) {
  if (!narrow) return filled ? IconButton.styleFrom(backgroundColor: AppColors.accent) : const ButtonStyle();
  final fg = filled ? Colors.white : null;
  return IconButton.styleFrom(
    minimumSize: const Size(30, 30),
    maximumSize: const Size(34, 34),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    backgroundColor: filled ? AppColors.accent : null,
    foregroundColor: fg,
  );
}

/// "3 min" / "2 h" / "10 d" - reminder offsets, not relative times.
String _shortDuration(Duration d) {
  if (d.inDays >= 1) return '${d.inDays} d';
  if (d.inHours >= 1) return '${d.inHours} h';
  return '${d.inMinutes} min';
}

/// Mon / Tue / ... for the compact phone day header.
String _weekdayShort(DateTime d) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[d.weekday - 1];
}

/// Locale clock time, e.g. "9:45 PM" / "21:45".
String _clockTime(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(t));

class _LeftTaskCellState extends ConsumerState<_LeftTaskCell> {
  @override
  Widget build(BuildContext context) {
    final svc = ref.read(supabaseServiceProvider);
    final loc = AppLocalizations.of(context)!;
    final task = widget.task;
    final hovered = widget.hovered;
    final rowBg = AppColors.surface;
    final bg = hovered ? Color.alphaBlend(AppColors.accent.withValues(alpha: 0.07), rowBg) : rowBg;
    final hoverSide = BorderSide(color: AppColors.accent, width: 1.5);
    // Note count for the menu label.
    final allCols = List.of(svc.columns)..sort((a, b) => a.position.compareTo(b.position));
    final noteCol = allCols.where((c) => c.id == 'col_note').firstOrNull ??
        allCols.where((c) => c.type == ColumnType.text && c.label.toLowerCase().contains('note')).firstOrNull;
    int noteCount = 0;
    if (noteCol != null) {
      noteCount = svc.entries.where((e) => e.taskId == task.id && notePlainText(e.data[noteCol.id]).isNotEmpty).length;
    }
    final noUpcomingDay = (task.reminder as String?)?.isNotEmpty == true && svc.nextAssignedEntry(task.id as String) == null;
    // On a phone-width task column the bell and the menu cannot both fit next
    // to the name, and the menu already lists the reminder.
    final mobile = MediaQuery.of(context).size.width < 600;
    // Same source of truth as the scheduler: spell out the time the reminder
    // will actually fire, so "3MI" never looks like "in 3 minutes".
    final remRaw = ((task.reminder as String?) ?? '').trim();
    final remInfo = remRaw.isEmpty ? null : svc.nextTaskReminder(task.id as String);
    final bellMsg = remInfo == null
        ? loc.bellTip(remRaw.toUpperCase())
        : remInfo.hasTime
            ? loc.bellTipBefore(_shortDuration(remInfo.offset), _clockTime(context, remInfo.when))
            : loc.bellTipBeforeDay(_shortDuration(remInfo.offset), formatDayHeader(remInfo.when));
    return MouseRegion(
      onEnter: (_) => widget.onHover(true),
      onExit: (_) => widget.onHover(false),
      child: Container(
        key: ValueKey('left-${task.id}'),
        height: 48,
        decoration: BoxDecoration(
          color: bg,
          boxShadow: widget.hScrolled ? [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 6, offset: const Offset(2, 0))] : null,
        ),
        // Painted on top so the hover outline never steals width from the
        // name + menu row below.
        foregroundDecoration: BoxDecoration(
          border: Border(
            bottom: hovered ? hoverSide : BorderSide(color: AppColors.border, width: 1),
            right: hovered ? hoverSide : BorderSide(color: AppColors.border),
            top: hovered ? hoverSide : BorderSide.none,
            left: hovered ? hoverSide : BorderSide.none,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: mobile ? 6 : 8),
        child: Row(children: [
          Expanded(child: InkWell(onTap: widget.onRename, borderRadius: BorderRadius.circular(8), child: Padding(padding: EdgeInsets.symmetric(vertical: 4, horizontal: mobile ? 2 : 0), child: Text(task.name.isEmpty ? '—' : task.name, style: TextStyle(fontSize: mobile ? 12.5 : 12, color: task.name.isEmpty ? AppColors.textSecondary : AppColors.textPrimary, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)))),
          if (!mobile && (task.reminder as String?)?.isNotEmpty == true)
            Tooltip(
              message: bellMsg,
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(Icons.notifications_outlined, size: 13, color: AppColors.accent),
              ),
            ),
          PopupMenuButton(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
            // IconButton defaults to a 40-48px tap target, which ate half of a
            // 148px task column and left ~4 characters for the name.
            style: mobile
                ? IconButton.styleFrom(minimumSize: const Size(30, 30), padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap)
                : null,
            itemBuilder: (_) => [
              // A per-task reminder counts back from the next scheduled
              // occurrence, so an unscheduled task would never fire: say so
              // instead of failing silently.
              if (noUpcomingDay)
                PopupMenuItem(
                  enabled: false,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFF59E0B)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(loc.reminderNoUpcomingDay, style: const TextStyle(fontSize: 10, color: Color(0xFFB45309)))),
                  ]),
                ),
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
  final bool mobile;
  final double dayColWidth;
  final double rowH;
  final bool showToggle;
  final bool hovered;
  final ValueChanged<bool> onHover;
  const _RightTaskRow({required this.task, required this.days, required this.cols, required this.isAlt, this.flashDayKey, required this.basic, required this.mobile, required this.dayColWidth, required this.rowH, required this.showToggle, required this.hovered, required this.onHover});
  @override
  ConsumerState<_RightTaskRow> createState() => _RightTaskRowState();
}

class _RightTaskRowState extends ConsumerState<_RightTaskRow> {
  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  double _widthFor(ColumnDefinition col) => widget.mobile
      ? widget.dayColWidth
      : (widget.basic && (col.type == ColumnType.timer || col.type == ColumnType.status)) ? 76.0 : 132.0;
  ColumnDefinition? get _statusCol {
    for (final c in widget.cols) {
      if (c.type == ColumnType.status) return c;
    }
    return null;
  }
  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(supabaseServiceProvider);
    final loc = AppLocalizations.of(context)!;
    final task = widget.task;
    final days = widget.days;
    final cols = widget.cols;
    final hovered = widget.hovered;
    // The row is the page colour and each day sits on it as its own block, so
    // the empty space between days reads as a gap. Painting the row flat is
    // what made a vertical rule necessary in the first place.
    final rowBg = AppColors.bg;
    final bg = hovered ? Color.alphaBlend(AppColors.accent.withValues(alpha: 0.07), rowBg) : rowBg;
    final hoverSide = BorderSide(color: AppColors.accent, width: 1.5);
    return MouseRegion(
      onEnter: (_) => widget.onHover(true),
      onExit: (_) => widget.onHover(false),
      child: Container(
        height: widget.rowH,
        decoration: BoxDecoration(color: bg),
        // Hover outline is painted on top: as a `decoration` border the 1.5px
        // right edge would shrink the row and overflow the day cells.
        foregroundDecoration: BoxDecoration(
          border: Border(
            bottom: hovered ? hoverSide : BorderSide(color: AppColors.border.withValues(alpha: 0.6), width: 1),
            top: hovered ? hoverSide : BorderSide.none,
            right: hovered ? hoverSide : BorderSide.none,
          ),
        ),
        child: Row(children: [
          for (int di = 0; di < days.length; di++) ...[
            Builder(builder: (_) {
              final d = days[di];
              final flash = widget.flashDayKey != null && _dateKey(d) == widget.flashDayKey;
              final flashBg = flash ? AppColors.accent.withValues(alpha: 0.07) : AppColors.surface;
              final sc = _statusCol;
              return Container(
                // Same leading gap as the header, so the two sections line up
                // and the space between dates is what separates them.
                padding: EdgeInsets.only(left: _dayGapFor(widget.mobile)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (widget.showToggle)
                  Container(
                      width: 48,
                      height: widget.rowH,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: flashBg),
                      child: Builder(builder: (_) {
                        final e = svc.entryFor(task.id, d);
                        final raw = sc == null ? null : e?.data[sc.id];
                        // Status dot assigns the day (idle = unassigned); legacy
                        // checkbox only when the workspace has no status column.
                        if (sc == null) {
                          final checked = e?.checked ?? false;
                          return Checkbox(value: checked, onChanged: (v) => svc.toggleChecked(task.id, d, v ?? false), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap);
                        }
                        return StatusDotButton(taskId: task.id, date: d, col: sc, rawValue: raw, title: loc.editColLabel(sc.label));
                      })),
                for (int ci = 0; ci < cols.length; ci++)
                  Container(
                      width: _widthFor(cols[ci]),
                      height: widget.rowH,
                      padding: EdgeInsets.symmetric(horizontal: widget.mobile ? 3 : 10, vertical: 8),
                      decoration: BoxDecoration(color: flashBg),
                      alignment: Alignment.center,
                      child: _Cell(taskId: task.id, date: d, col: cols[ci], mobile: widget.mobile)),
                ]),
              );
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
  final bool mobile;
  const _Cell({required this.taskId, required this.date, required this.col, this.mobile = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(supabaseServiceProvider);
    // Phones always get the dot: the full status dropdown is 132px wide and
    // cannot fit a 7-day strip.
    final basic = mobile || ref.watch(displayPrefsProvider).basicCells;
    final loc = AppLocalizations.of(context)!;
    final e = svc.entryFor(taskId, date);
    final raw = e?.valueFor(col.id);
    switch (col.type) {
      case ColumnType.checkbox:
        return Checkbox(value: raw == true, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v), visualDensity: VisualDensity.compact);
      case ColumnType.schedule:
        return ScheduleCell(value: raw as String?, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v));
      case ColumnType.status:
        // Soft tinted pill instead of a bordered dropdown: the old cell was
        // the main source of contrast complaints on the weekly page.
        return SoftStatusPill(taskId: taskId, date: date, col: col, rawValue: raw, title: loc.editColLabel(col.label));
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
        return TagCell(selectedIds: ids, col: col, onChanged: (v) => svc.setCellValue(taskId, date, col.id, v));
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
