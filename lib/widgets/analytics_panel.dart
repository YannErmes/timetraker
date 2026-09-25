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
class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(supabaseServiceProvider);
    final t = AppLocalizations.of(context)!;
    final tasks = List.of(svc.tasks)..sort((a, b) => a.position.compareTo(b.position));
    final entries = svc.entries;
    final cols = svc.columns;
    final statusCol = cols.where((c) => c.type.name == 'status').firstOrNull;
    final timerCol = cols.where((c) => c.type.name == 'timer').firstOrNull;

    String? statusOf(e) => statusCol == null ? null : e.data[statusCol.id] as String?;
    int timerSecOf(e) {
      if (timerCol == null) return 0;
      final tv = TimerValue.tryParse(e.data[timerCol.id]);
      return tv?.durationSec ?? 0;
    }

    final scheduled = entries.where((e) => e.checked).toList();
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
              child: _WeeklyChart(scheduled: scheduled, statusOf: statusOf, t: t),
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
  const _WeeklyChart({required this.scheduled, required this.statusOf, required this.t});

  @override
  Widget build(BuildContext context) {
    final now = normalizeDate(DateTime.now());
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final List<({DateTime start, int total, int done})> weeks = List.generate(8, (i) {
      final start = monday.subtract(Duration(days: 7 * (7 - i)));
      final end = start.add(const Duration(days: 6));
      final inWeek = scheduled.where((e) {
        final d = normalizeDate(e.date as DateTime);
        return !d.isBefore(start) && !d.isAfter(end);
      }).toList();
      final done = inWeek.where((e) => statusOf(e) == 'done').length;
      return (start: start, total: inWeek.length, done: done);
    });
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
