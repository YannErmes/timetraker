import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../config/ui_style.dart';
import '../models/column_definition.dart';
import '../models/enums.dart';
import '../providers/app_providers.dart';
import '../utils/date_utils.dart';
import 'cells/cell_widgets.dart';
import 'cells/compact_cell.dart';
import 'cells/timer_cell.dart';
import 'note_editor_panel.dart';

/// Mind-map pool layout for Weekly: every task is a draggable rounded
/// square. Links auto-connect the selected day's tasks in schedule-time
/// order. Hover a node for quick actions; tap it to open its day.
class TaskPool extends ConsumerStatefulWidget {
  final List<dynamic> tasks; // filtered, position-sorted
  final List<ColumnDefinition> cols; // all columns (for time/status/note resolution)
  final DateTime date; // selected day driving the time links
  const TaskPool({super.key, required this.tasks, required this.cols, required this.date});

  @override
  ConsumerState<TaskPool> createState() => _TaskPoolState();
}

class _TaskPoolState extends ConsumerState<TaskPool> {
  static const baseW = 184.0;
  static const baseH = 128.0;
  static const canvasW = 4000.0;
  static const canvasH = 3000.0;

  final _transCtrl = TransformationController();
  final Map<String, Offset> _pos = {};
  double _scale = 1.0;
  String _fitKey = '';
  BoxConstraints? _viewport;

  double get _nodeW => baseW * _scale;
  double get _nodeH => baseH * _scale;

  @override
  void initState() {
    super.initState();
    _syncPositions();
  }

  @override
  void didUpdateWidget(covariant TaskPool oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPositions();
  }

  @override
  void dispose() {
    _transCtrl.dispose();
    super.dispose();
  }

  DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);

  int? _timeMinutes(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1].substring(0, 2));
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  String? _scheduleOf(dynamic task) {
    final svc = ref.read(supabaseServiceProvider);
    final e = svc.entryFor(task.id as String, widget.date);
    if (e == null || !svc.isAssigned(e)) return null;
    final schedCol = widget.cols.where((c) => c.id == 'col_schedule' || c.type == ColumnType.schedule).firstOrNull;
    if (schedCol == null) return null;
    return e.data[schedCol.id] as String?;
  }

  /// Task ids chained by schedule time for the selected day.
  List<String> _chainIds() {
    final timed = <MapEntry<String, int>>[];
    for (final t in widget.tasks) {
      final mins = _timeMinutes(_scheduleOf(t));
      if (mins != null) timed.add(MapEntry(t.id as String, mins));
    }
    timed.sort((a, b) => a.value.compareTo(b.value));
    return timed.map((e) => e.key).toList();
  }

  void _syncPositions() {
    // Order: today's time-chain first (reads left-to-right, top-to-bottom),
    // then everything else — laid out in a compact grid so every task
    // starts on screen.
    final chain = _chainIds();
    final ordered = <String>[
      ...chain,
      for (final t in widget.tasks)
        if (!chain.contains(t.id as String)) t.id as String,
    ];
    for (int i = 0; i < ordered.length; i++) {
      final id = ordered[i];
      if (_pos.containsKey(id)) continue;
      _pos[id] = Offset(160.0 + (i % 5) * 300.0, 140.0 + (i ~/ 5) * 260.0);
    }
    _pos.removeWhere((id, _) => !widget.tasks.any((t) => (t.id as String) == id));
    // Refit the camera whenever the task set changes so ALL tasks are visible.
    final key = ordered.join(',');
    if (key != _fitKey) {
      _fitKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
    }
  }

  /// Zoom/pan so every node fits inside the current viewport.
  void _fitAll() {
    final vp = _viewport;
    if (vp == null || _pos.isEmpty || !mounted) return;
    double minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
    for (final p in _pos.values) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx + _nodeW);
      maxY = math.max(maxY, p.dy + _nodeH);
    }
    final contentW = math.max(1.0, maxX - minX);
    final contentH = math.max(1.0, maxY - minY);
    final s = math.min(vp.maxWidth / contentW, vp.maxHeight / contentH).clamp(0.2, 1.0);
    final tx = (vp.maxWidth - contentW * s) / 2 - minX * s;
    final ty = (vp.maxHeight - contentH * s) / 2 - minY * s;
    _transCtrl.value = Matrix4.identity()
      ..scale(s)
      ..setTranslationRaw(tx, ty, 0);
  }

  void _openDay(String taskId) {
    final svc = ref.read(supabaseServiceProvider);
    final normSel = _norm(widget.date);
    final dates = svc.entries
        .where((e) => e.taskId == taskId && svc.isAssigned(e))
        .map((e) => _norm(e.date as DateTime))
        .toSet()
        .toList()
      ..sort();
    DateTime target = normSel;
    if (!dates.contains(normSel) && dates.isNotEmpty) {
      final now = _norm(DateTime.now());
      final upcoming = dates.where((d) => !d.isBefore(now)).toList();
      target = upcoming.isEmpty ? dates.last : upcoming.first;
    }
    ref.read(selectedDateProvider.notifier).state = target;
    ref.read(viewModeProvider.notifier).state = ViewMode.daily;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final svc = ref.watch(supabaseServiceProvider);
    final chain = _chainIds();
    return LayoutBuilder(builder: (_, viewport) {
      _viewport = viewport;
      return Stack(children: [
      InteractiveViewer(
        transformationController: _transCtrl,
        boundaryMargin: const EdgeInsets.all(1200),
        minScale: 0.15,
        maxScale: 2.5,
        child: SizedBox(
          width: _TaskPoolState.canvasW,
          height: _TaskPoolState.canvasH,
          child: Stack(children: [
            CustomPaint(
              size: const Size(_TaskPoolState.canvasW, _TaskPoolState.canvasH),
              painter: _LinkPainter(positions: Map.of(_pos), order: chain, nodeW: _nodeW, nodeH: _nodeH),
            ),
            for (final task in widget.tasks)
              if (_pos.containsKey(task.id as String))
                Positioned(
                  left: _pos[task.id as String]!.dx,
                  top: _pos[task.id as String]!.dy,
                  child: _PoolNode(
                    task: task,
                    date: widget.date,
                    cols: widget.cols,
                    width: _nodeW,
                    height: _nodeH,
                    highlight: (() { final he = svc.entryFor(task.id as String, widget.date); return he != null && svc.isAssigned(he); })(),
                    onMoved: (d) => setState(() {
                      final p = _pos[task.id as String]!;
                      _pos[task.id as String] = p + d;
                    }),
                    onOpenDay: () => _openDay(task.id as String),
                  ),
                ),
          ]),
        ),
      ),
      Positioned(
        left: 12,
        top: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.header, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
          child: Text(t.tasksCount('${widget.tasks.length}'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
      ),
      Positioned(
        left: 12,
        bottom: 12,
        child: Container(
          width: 190,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.header, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Icon(Icons.photo_size_select_small_rounded, size: 15, color: AppColors.textSecondary),
            Expanded(
              child: Slider(
                value: _scale,
                min: 0.7,
                max: 1.5,
                divisions: 8,
                label: t.poolSize,
                activeColor: AppColors.accent,
                onChanged: (v) => setState(() => _scale = v),
              ),
            ),
          ]),
        ),
      ),
      Positioned(
        right: 12,
        bottom: 12,
        child: FloatingActionButton.small(
          backgroundColor: AppColors.inputFill,
          foregroundColor: AppColors.textSecondary,
          tooltip: t.poolReset,
          onPressed: () => setState(_fitAll),
          child: const Icon(Icons.center_focus_strong_rounded, size: 18),
        ),
      ),
      ]);
    });
  }
}

/// Lines + arrowheads connecting chained nodes (time order).
class _LinkPainter extends CustomPainter {
  final Map<String, Offset> positions;
  final List<String> order;
  final double nodeW;
  final double nodeH;
  const _LinkPainter({required this.positions, required this.order, required this.nodeW, required this.nodeH});

  @override
  void paint(Canvas canvas, Size size) {
    if (order.length < 2) return;
    final line = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.55)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = AppColors.accent;
    for (int i = 0; i < order.length - 1; i++) {
      final a = positions[order[i]];
      final b = positions[order[i + 1]];
      if (a == null || b == null) continue;
      final p1 = a + Offset(nodeW / 2, nodeH / 2);
      final p2 = b + Offset(nodeW / 2, nodeH / 2);
      final dir = (p2 - p1);
      final len = dir.distance;
      if (len < 1) continue;
      final unit = dir / len;
      // trim to node edges (approx with node half-diagonal margin)
      const margin = 70.0;
      final s = p1 + unit * margin;
      final e = p2 - unit * margin;
      if ((e - s).distance < 4) continue;
      canvas.drawLine(s, e, line);
      // arrowhead
      const head = 12.0;
      final ang = unit.direction;
      canvas.drawLine(e, e - Offset.fromDirection(ang - 0.45, head), line..strokeWidth = 2.5);
      canvas.drawLine(e, e - Offset.fromDirection(ang + 0.45, head), line);
      canvas.drawCircle(s, 4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LinkPainter old) => old.positions != positions || old.order != order;
}

class _PoolNode extends ConsumerStatefulWidget {
  final dynamic task;
  final DateTime date;
  final List<ColumnDefinition> cols;
  final double width;
  final double height;
  final bool highlight; // scheduled for the shown day -> tinted contour
  final ValueChanged<Offset> onMoved;
  final VoidCallback onOpenDay;
  const _PoolNode(
      {required this.task, required this.date, required this.cols, required this.width, required this.height, required this.highlight, required this.onMoved, required this.onOpenDay});

  @override
  ConsumerState<_PoolNode> createState() => _PoolNodeState();
}

class _PoolNodeState extends ConsumerState<_PoolNode> {
  bool _hover = false;

  ColumnDefinition? get _statusCol => widget.cols.where((c) => c.type == ColumnType.status).firstOrNull;
  ColumnDefinition? get _timerCol =>
      widget.cols.where((c) => c.id == 'col_time' || c.type == ColumnType.timer).firstOrNull;
  ColumnDefinition? get _noteCol => widget.cols.where((c) => c.id == 'col_note').firstOrNull;

  String? _timeLabel() {
    final svc = ref.read(supabaseServiceProvider);
    final e = svc.entryFor(widget.task.id as String, widget.date);
    if (e == null || !svc.isAssigned(e)) return null;
    final schedCol = widget.cols.where((c) => c.id == 'col_schedule' || c.type == ColumnType.schedule).firstOrNull;
    final raw = schedCol == null ? null : e.data[schedCol.id] as String?;
    if (raw == null || raw.isEmpty) return null;
    // "HH:mm" -> locale display
    final parts = raw.split(':');
    final h = int.tryParse(parts[0]);
    final m = parts.length > 1 ? int.tryParse(parts[1].substring(0, 2)) ?? 0 : 0;
    if (h == null) return raw;
    return TimeOfDay(hour: h, minute: m).format(context);
  }

  Color _statusColor() {
    final svc = ref.read(supabaseServiceProvider);
    final sc = _statusCol;
    final raw = sc == null ? null : svc.entryFor(widget.task.id as String, widget.date)?.data[sc.id] as String?;
    switch (raw) {
      case 'done':
        return const Color(0xFF22C55E);
      case 'cancel':
        return const Color(0xFFF43F5E);
      case 'in_progress':
      case 'in progress':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.textSecondary;
    }
  }

  void _openStatus(AppLocalizations t) {
    final sc = _statusCol;
    if (sc == null) return;
    final svc = ref.read(supabaseServiceProvider);
    final raw = svc.entryFor(widget.task.id as String, widget.date)?.data[sc.id] as String?;
    showCellEditorDialog(context,
        title: t.editColLabel(sc.label),
        editor: StatusCell(
            valueId: raw,
            options: sc.statusOptions,
            onChanged: (v) => svc.setCellValue(widget.task.id as String, widget.date, sc.id, v)));
  }

  void _openTimer(AppLocalizations t) {
    final tc = _timerCol;
    if (tc == null) return;
    final svc = ref.read(supabaseServiceProvider);
    final raw = svc.entryFor(widget.task.id as String, widget.date)?.data[tc.id];
    showCellEditorDialog(context,
        title: t.editColLabel(tc.label),
        editor: TimerCell(taskId: widget.task.id as String, date: widget.date, columnId: tc.id, rawValue: raw));
  }

  void _openNote() {
    final nc = _noteCol;
    if (nc == null) return;
    ref.read(noteEditorRequestProvider.notifier).state = NoteEditorRequest(
        taskId: widget.task.id as String, date: widget.date, columnId: nc.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final name = ((widget.task.name ?? '') as String).isEmpty ? t.untitledCap : widget.task.name as String;
    final time = _timeLabel();
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onOpenDay,
        onPanUpdate: (d) => widget.onMoved(d.delta),
        child: SizedBox(
          width: widget.width,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedOpacity(
              opacity: _hover ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: _hover
                  ? Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.header, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (_timerCol != null)
                          _miniBtn(Icons.hourglass_bottom_rounded, t.timeDurationLbl, _openTimer),
                        if (_noteCol != null) _miniBtn(Icons.notes_rounded, t.noteLbl, (_) => _openNote()),
                        if (_statusCol != null) _miniBtn(Icons.flag_outlined, t.statusLbl, _openStatus),
                        _miniBtn(Icons.open_in_new_rounded, t.openDailyBtn, (_) => widget.onOpenDay()),
                      ]),
                    )
                  : const SizedBox(height: 0),
            ),
            Container(
              width: widget.width,
              height: widget.height,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: _hover
                        ? AppColors.accent
                        : (widget.highlight ? AppColors.accent.withValues(alpha: 0.55) : AppColors.border),
                    width: _hover ? 2 : 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3)),
                  ...UiStyle.neuCard(blur: 10, dist: 4),
                ],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _statusColor(), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  if (time != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
                      child: Text(time, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)),
                    ),
                ]),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 3, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, String tooltip, void Function(AppLocalizations) onTap) {
    final t = AppLocalizations.of(context)!;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onTap(t),
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: AppColors.accent),
        ),
      ),
    );
  }
}
