import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../config/ui_style.dart';
import '../models/timer_value.dart';
import '../providers/app_providers.dart';
import '../utils/date_utils.dart';

/// Analytics dashboard page: overview cards, 8-week progress chart,
/// status donut, time per task, and per-task completion bars.
class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});
  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  DateTime? _from;
  DateTime? _to;

  DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);
  String _fmt(DateTime? d) => d == null ? '—' : '${d.month}/${d.day}/${d.year}';

  Future<void> _pick(bool isFrom) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d == null) return;
    setState(() {
      if (isFrom) {
        _from = d;
        if (_to != null && _norm(d).isAfter(_norm(_to!))) _to = d;
      } else {
        _to = d;
        if (_from != null && _norm(_from!).isAfter(_norm(d))) _from = d;
      }
    });
  }

  void _preset(int days) {
    final now = _norm(DateTime.now());
    setState(() {
      _to = now;
      _from = now.subtract(Duration(days: days - 1));
    });
  }

  Widget _dateBox(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              Text(_fmt(value), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    final active = label == '7D'
        ? _from != null && _to != null && _norm(_to!).difference(_norm(_from!)).inDays == 6
        : label == '30D'
            ? _from != null && _to != null && _norm(_to!).difference(_norm(_from!)).inDays == 29
            : _from == null && _to == null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AppColors.accent : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(supabaseServiceProvider);
    final t = AppLocalizations.of(context)!;
    final tasks = List.of(svc.tasks)..sort((a, b) => a.position.compareTo(b.position));
    final entries = svc.entries;
    final cols = svc.columns;
    final statusCol = cols.where((c) => c.type.name == 'status').firstOrNull;
    final timerCol = cols.where((c) => c.type.name == 'timer').firstOrNull;

    String? statusOf(dynamic e) =>
        (statusCol == null || e == null) ? null : (e.data[statusCol.id] as String?);
    int timerSecOf(e) {
      if (timerCol == null) return 0;
      final tv = TimerValue.tryParse(e.data[timerCol.id]);
      return tv?.durationSec ?? 0;
    }

    final scheduledAll = entries.where((e) => svc.isAssigned(e)).toList();
    // Timeline filter (date 1 → date 2); empty ends mean open range.
    final scheduled = scheduledAll.where((e) {
      final d = _norm(e.date as DateTime);
      if (_from != null && d.isBefore(_norm(_from!))) return false;
      if (_to != null && d.isAfter(_norm(_to!))) return false;
      return true;
    }).toList();
    final doneCount = scheduled.where((e) => statusOf(e) == 'done').length;
    final totalSec = scheduled.fold(0, (s, e) => s + timerSecOf(e));
    final doneSec = scheduled.where((e) => statusOf(e) == 'done').fold(0, (s, e) => s + timerSecOf(e));
    final pct = scheduled.isEmpty ? 0.0 : doneCount / scheduled.length;
    final distinctDays = scheduled.map((e) => e.dateKey).toSet().length;

    return Container(
      color: AppColors.bg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Icon(Icons.analytics_outlined, size: 20, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.analytics, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(t.analyticsSubtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
            _Card(
              title: t.timelineTitle,
              child: Column(children: [
                Row(children: [
                  Expanded(child: _dateBox(t.fromLbl, _from, () => _pick(true))),
                  const SizedBox(width: 8),
                  Expanded(child: _dateBox(t.toLbl, _to, () => _pick(false))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _presetChip('7D', () => _preset(7)),
                  const SizedBox(width: 6),
                  _presetChip('30D', () => _preset(30)),
                  const SizedBox(width: 6),
                  _presetChip(t.allTimeBtn, () => setState(() {
                        _from = null;
                        _to = null;
                      })),
                ]),
              ]),
            ),
            _Card(
              title: t.scheduledChip,
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                _Stat(Icons.list_alt_rounded, t.scheduledChip, t.slotsDays('${scheduled.length}', '$distinctDays'), AppColors.textPrimary),
                _Stat(Icons.check_circle_rounded, t.doneChipA, '${(pct * 100).toStringAsFixed(0)}% ($doneCount)', const Color(0xFF22C55E)),
                _Stat(Icons.schedule_rounded, t.timePlanned, TimerValue.formatSec(totalSec), AppColors.accent),
                _Stat(Icons.hourglass_bottom_rounded, t.timeDone, TimerValue.formatSec(doneSec), const Color(0xFF22C55E)),
              ]),
            ),
            _Card(
              title: t.weeklyProgress,
              child:             _WeeklyChart(scheduled: scheduled, statusOf: statusOf, t: t, from: _from, to: _to),
            ),
            _Card(
              title: t.statusBreakdown,
              child: _StatusDonut(scheduled: scheduled, statusOf: statusOf, t: t),
            ),
            _Card(
              title: t.timePerTask,
              child: tasks.isEmpty
                  ? _Empty(text: t.noTasksYet)
                  : Column(
                      children: [
                        for (final task in tasks)
                          Builder(builder: (_) {
                            final mine = scheduled.where((e) => e.taskId == task.id).toList();
                            final secs = mine.fold(0, (s, e) => s + timerSecOf(e));
                            return _TimeRow(name: task.name.isEmpty ? t.untitledLower : task.name, seconds: secs, maxSeconds: _maxTime(tasks, scheduled, timerSecOf));
                          }),
                      ],
                    ),
            ),
            _Card(
              title: t.completionPerTask,
              child: tasks.isEmpty
                  ? _Empty(text: t.noTasksYet)
                  : Column(
                      children: [
                        for (final task in tasks)
                          Builder(builder: (_) {
                            final mine = scheduled.where((e) => e.taskId == task.id).toList();
                            final total = mine.length;
                            final done = mine.where((e) => statusOf(e) == 'done').length;
                            final p = total == 0 ? 0.0 : done / total;
                            final recent = mine.isEmpty ? null : (mine..sort((a, b) => a.date.compareTo(b.date))).last;
                            final barColor = _barColor(statusOf(recent));
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(children: [
                                Expanded(flex: 3, child: Text(task.name.isEmpty ? t.untitledLower : task.name, style: TextStyle(fontSize: 12, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 8),
                                Expanded(
                                    flex: 4,
                                    child: LinearProgressIndicator(
                                        value: p,
                                        backgroundColor: AppColors.inputFill,
                                        valueColor: AlwaysStoppedAnimation(total == 0 ? const Color(0xFF475569) : barColor),
                                        borderRadius: BorderRadius.circular(8),
                                        minHeight: 7)),
                                const SizedBox(width: 8),
                                Text('$done/$total', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(width: 4),
                                SizedBox(width: 40, child: Text('${(p * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary), textAlign: TextAlign.right)),
                              ]),
                            );
                          }),
                      ],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _maxTime(tasks, scheduled, int Function(dynamic) timerSecOf) {
    int m = 1;
    for (final t in tasks) {
      final s = scheduled.where((e) => e.taskId == t.id).fold(0, (a, e) => (a as int) + timerSecOf(e));
      if (s > m) m = s;
    }
    return m;
  }

  Color _barColor(String? status) {
    switch (status) {
      case 'in_progress':
      case 'in progress':
        return const Color(0xFFF59E0B);
      case 'cancel':
      case 'cancelled':
        return const Color(0xFFF43F5E);
      case 'done':
        return const Color(0xFF22C55E);
      default:
        return AppColors.accent;
    }
  }
}

/// Rounded section card used by the dashboard.
class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: UiStyle.neuCard(blur: 10, dist: 4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _Stat(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 7),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ]),
      ]),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<dynamic> scheduled;
  final String? Function(dynamic) statusOf;
  final AppLocalizations t;
  final DateTime? from;
  final DateTime? to;
  const _WeeklyChart({required this.scheduled, required this.statusOf, required this.t, this.from, this.to});

  DateTime _monday(DateTime d) {
    final n = DateTime(d.year, d.month, d.day);
    return n.subtract(Duration(days: n.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final now = normalizeDate(DateTime.now());
    // Buckets follow the selected timeline; default = last 8 weeks.
    final endMon = _monday(to ?? now);
    DateTime startMon;
    if (from != null) {
      startMon = _monday(from!);
    } else if (to != null) {
      startMon = endMon.subtract(const Duration(days: 7 * 7));
    } else {
      startMon = endMon.subtract(const Duration(days: 7 * 7));
    }
    final starts = <DateTime>[];
    var cur = startMon;
    while (!cur.isAfter(endMon) && starts.length < 26) {
      starts.add(cur);
      cur = cur.add(const Duration(days: 7));
    }
    final weeks = starts.map((start) {
      final end = start.add(const Duration(days: 6));
      final inWeek = scheduled.where((e) {
        final d = normalizeDate(e.date as DateTime);
        return !d.isBefore(start) && !d.isAfter(end);
      }).toList();
      final done = inWeek.where((e) => statusOf(e) == 'done').length;
      return (start: start, total: inWeek.length, done: done);
    }).toList();
    final maxTotal = weeks.fold(1, (m, w) => w.total > m ? w.total : m);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int wi = 0; wi < weeks.length; wi++)
            Builder(builder: (_) {
              final w = weeks[wi];
              final isCurrent = wi == weeks.length - 1;
              return Tooltip(
                message: '${w.start.month}/${w.start.day} — ${t.scheduledOf('${w.done}', '${w.total}')}',
                child: Container(
                  width: 56,
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: isCurrent
                      ? BoxDecoration(color: AppColors.accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10))
                      : null,
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Text('${w.done}/${w.total}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isCurrent ? AppColors.accent : AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Container(
                      height: 96,
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 22,
                        height: (96 * (w.total == 0 ? 0.04 : w.total / maxTotal)).clamp(5.0, 96.0),
                        decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(7)),
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: w.total == 0 ? 0 : w.done / w.total,
                          widthFactor: 1,
                          child: Container(decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(7))),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text('${w.start.month}/${w.start.day}', style: TextStyle(fontSize: 9, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400, color: isCurrent ? AppColors.accent : AppColors.textSecondary)),
                  ]),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StatusDonut extends StatelessWidget {
  final List<dynamic> scheduled;
  final String? Function(dynamic) statusOf;
  final AppLocalizations t;
  const _StatusDonut({required this.scheduled, required this.statusOf, required this.t});

  @override
  Widget build(BuildContext context) {
    int done = 0, prog = 0, cancel = 0, none = 0;
    for (final e in scheduled) {
      switch (statusOf(e)) {
        case 'done':
          done++;
          break;
        case 'in_progress':
        case 'in progress':
          prog++;
          break;
        case 'cancel':
        case 'cancelled':
          cancel++;
          break;
        default:
          none++;
      }
    }
    final total = scheduled.isEmpty ? 1 : scheduled.length;
    final segs = [
      (done, const Color(0xFF22C55E), t.doneLeg),
      (prog, const Color(0xFFF59E0B), t.progLeg),
      (cancel, const Color(0xFFF43F5E), t.cancelLeg),
      (none, AppColors.textSecondary, t.plannedLeg),
    ];
    return Row(children: [
      SizedBox(
        width: 120,
        height: 120,
        child: CustomPaint(
          painter: _DonutPainter(values: segs.map((s) => s.$1).toList(), colors: segs.map((s) => s.$2).toList(), empty: scheduled.isEmpty),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(scheduled.isEmpty ? '—' : '${(done / scheduled.length * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              Text(t.doneLeg, style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final s in segs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: s.$2, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Expanded(child: Text(s.$3, style: TextStyle(fontSize: 11, color: AppColors.textPrimary))),
                Text('${s.$1} · ${(s.$1 / total * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  final List<int> values;
  final List<Color> colors;
  final bool empty;
  const _DonutPainter({required this.values, required this.colors, required this.empty});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const stroke = 16.0;
    if (empty) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 0, math.pi * 2, false,
          Paint()..color = const Color(0xFF475569)..style = PaintingStyle.stroke..strokeWidth = stroke);
      return;
    }
    final total = values.fold(0, (a, b) => a + b);
    double start = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        Paint()..color = colors[i]..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.values != values || old.colors != colors || old.empty != empty;
}

class _TimeRow extends StatelessWidget {
  final String name;
  final int seconds;
  final int maxSeconds;
  const _TimeRow({required this.name, required this.seconds, required this.maxSeconds});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Text(name, style: TextStyle(fontSize: 11, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: Container(
            height: 9,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (seconds / maxSeconds).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.6)]),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 60, child: Text(TimerValue.formatSec(seconds), style: TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.right)),
      ]),
    );
  }
}
