import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../config/ui_style.dart';
import '../models/timer_value.dart';
import '../providers/app_providers.dart';
import '../utils/date_utils.dart';

/// Rich analytics dashboard: overview chips, 8-week progress chart,
/// status breakdown, time per task, and per-task completion bars.
class AnalyticsDialog extends ConsumerWidget {
  const AnalyticsDialog({super.key});

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

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.border)),
      title: Row(children: [
        Icon(Icons.analytics_outlined, size: 18, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(t.analytics, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      ]),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ---- overview chips ----
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip(Icons.list_alt_rounded, t.scheduledChip, t.slotsDays('${scheduled.length}', '$distinctDays'), AppColors.textPrimary),
              _chip(Icons.check_circle_rounded, t.doneChipA, '${(pct * 100).toStringAsFixed(0)}% ($doneCount)', const Color(0xFF22C55E)),
              _chip(Icons.schedule_rounded, t.timePlanned, TimerValue.formatSec(totalSec), AppColors.accent),
              _chip(Icons.hourglass_bottom_rounded, t.timeDone, TimerValue.formatSec(doneSec), const Color(0xFF22C55E)),
            ]),
            const SizedBox(height: 16),
            _sectionTitle(t.weeklyProgress),
            const SizedBox(height: 8),
            _WeeklyChart(scheduled: scheduled, statusOf: statusOf),
            const SizedBox(height: 16),
            _sectionTitle(t.statusBreakdown),
            const SizedBox(height: 8),
            _StatusBreakdown(scheduled: scheduled, statusOf: statusOf, t: t),
            const SizedBox(height: 16),
            _sectionTitle(t.timePerTask),
            const SizedBox(height: 8),
            if (tasks.isEmpty)
              Text(t.noTasksYet, style: TextStyle(color: AppColors.textSecondary))
            else
              for (final task in tasks)
                Builder(builder: (_) {
                  final mine = scheduled.where((e) => e.taskId == task.id).toList();
                  final secs = mine.fold(0, (s, e) => s + timerSecOf(e));
                  return _TimeRow(name: task.name.isEmpty ? t.untitledLower : task.name, seconds: secs, maxSeconds: _maxTime(tasks, scheduled, timerSecOf));
                }),
            const SizedBox(height: 16),
            _sectionTitle(t.completionPerTask),
            const SizedBox(height: 8),
            if (tasks.isEmpty)
              Text(t.noTasksYet, style: TextStyle(color: AppColors.textSecondary))
            else
              for (final task in tasks)
                Builder(builder: (_) {
                  final mine = scheduled.where((e) => e.taskId == task.id).toList();
                  final total = mine.length;
                  final done = mine.where((e) => statusOf(e) == 'done').length;
                  final p = total == 0 ? 0.0 : done / total;
                  final recent = mine.isEmpty
                      ? null
                      : (mine..sort((a, b) => a.date.compareTo(b.date))).last;
                  final barColor = _barColor(statusOf(recent));
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text(task.name.isEmpty ? t.untitledLower : task.name, style: TextStyle(fontSize: 12, color: AppColors.textPrimary))),
                      SizedBox(
                          width: 120,
                          child: LinearProgressIndicator(
                              value: p, backgroundColor: AppColors.inputFill, valueColor: AlwaysStoppedAnimation(total == 0 ? const Color(0xFF475569) : barColor), borderRadius: BorderRadius.circular(8), minHeight: 6)),
                      const SizedBox(width: 8),
                      Text('${(p * 100).toStringAsFixed(0)}% ($done/$total)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  );
                }),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.close))],
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

  Widget _sectionTitle(String text) => Text(text, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12));

  Widget _chip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: UiStyle.neuCard(blur: 8, dist: 3),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text('$label: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<dynamic> scheduled;
  final String? Function(dynamic) statusOf;
  const _WeeklyChart({required this.scheduled, required this.statusOf});

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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final w in weeks)
            Expanded(
              child: Tooltip(
                message: '${w.start.month}/${w.start.day} — ${w.done}/${w.total} done',
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('${w.done}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Container(
                    height: 90,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 18,
                      height: (90 * (w.total == 0 ? 0.04 : w.total / maxTotal)).clamp(4.0, 90.0),
                      decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6)),
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: w.total == 0 ? 0 : w.done / w.total,
                        widthFactor: 1,
                        child: Container(decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(6))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${w.start.month}/${w.start.day}', style: TextStyle(fontSize: 8, color: AppColors.textSecondary)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  final List<dynamic> scheduled;
  final String? Function(dynamic) statusOf;
  final AppLocalizations t;
  const _StatusBreakdown({required this.scheduled, required this.statusOf, required this.t});

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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(children: [
          for (final s in segs)
            if (s.$1 > 0)
              Expanded(
                flex: s.$1,
                child: Container(height: 12, color: s.$2),
              ),
          if (scheduled.isEmpty) Expanded(child: Container(height: 12, color: AppColors.inputFill)),
        ]),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final s in segs)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: s.$2, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('${s.$3} ${s.$1} (${(s.$1 / total * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ]),
        ],
      ),
    ]);
  }
}

class _TimeRow extends StatelessWidget {
  final String name;
  final int seconds;
  final int maxSeconds;
  const _TimeRow({required this.name, required this.seconds, required this.maxSeconds});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 150,
          child: Text(name, style: TextStyle(fontSize: 11, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8)),
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
        SizedBox(width: 64, child: Text(TimerValue.formatSec(seconds), style: TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.right)),
      ]),
    );
  }
}
