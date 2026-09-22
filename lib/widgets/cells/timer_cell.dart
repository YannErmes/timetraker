import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../models/timer_value.dart';
import '../../providers/app_providers.dart';

class TimerCell extends ConsumerStatefulWidget {
  final String taskId;
  final DateTime date;
  final String columnId;
  final dynamic rawValue; // stored json map or null
  const TimerCell({super.key, required this.taskId, required this.date, required this.columnId, required this.rawValue});
  @override
  ConsumerState<TimerCell> createState() => _TimerCellState();
}

class _TimerCellState extends ConsumerState<TimerCell> {
  Timer? _ticker;
  @override
  void initState() {
    super.initState();
    _maybeStartTicker();
  }

  @override
  void didUpdateWidget(covariant TimerCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeStartTicker();
  }

  void _maybeStartTicker() {
    final tv = TimerValue.tryParse(widget.rawValue);
    final running = tv?.running ?? false;
    if (running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tv = TimerValue.tryParse(widget.rawValue);
    if (tv == null || tv.durationSec == 0) {
      return _EmptyTimer(onSet: _promptDuration);
    }
    final eff = tv.effectiveElapsed(DateTime.now());
    final progress = tv.progress;
    final isDone = tv.isComplete;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openTimerDialog(tv),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDone ? AppColors.doneBorder : AppColors.inputBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(color: isDone ? AppColors.doneFill : AppColors.accent.withValues(alpha: 0.85)),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '${TimerValue.formatSec(eff)} / ${TimerValue.formatSec(tv.durationSec)}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isDone ? AppColors.doneText : Colors.white, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 2)]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (tv.running)
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(child: Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.8), blurRadius: 4)]))),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptDuration() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
        title: const Text('Set duration', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(labelText: 'e.g. 4h, 30min, 1h 20m', hintText: '4h'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (res != null && res.trim().isNotEmpty) {
      final sec = TimerValue.parseDurationToSec(res.trim());
      if (sec > 0) {
        final tv = TimerValue(durationSec: sec, elapsedSec: 0, running: false);
        await ref.read(supabaseServiceProvider).setCellValue(widget.taskId, widget.date, widget.columnId, tv.toJson());
      }
    }
  }

  void _openTimerDialog(TimerValue tv) {
    showDialog(
      context: context,
      builder: (_) => _TimerDialog(taskId: widget.taskId, date: widget.date, columnId: widget.columnId, initial: tv),
    );
  }
}

class _EmptyTimer extends StatelessWidget {
  final VoidCallback onSet;
  const _EmptyTimer({required this.onSet});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onSet,
      child: Container(
        height: 32,
        decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder, style: BorderStyle.solid)),
        alignment: Alignment.center,
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.hourglass_empty, size: 12, color: AppColors.textSecondary),
          SizedBox(width: 4),
          Flexible(child: Text('Set duration', style: TextStyle(fontSize: 10, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

class _TimerDialog extends ConsumerStatefulWidget {
  final String taskId;
  final DateTime date;
  final String columnId;
  final TimerValue initial;
  const _TimerDialog({required this.taskId, required this.date, required this.columnId, required this.initial});
  @override
  ConsumerState<_TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends ConsumerState<_TimerDialog> {
  late TimerValue _tv;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _tv = widget.initial;
    _startTickerIfNeeded();
  }

  void _startTickerIfNeeded() {
    _ticker?.cancel();
    if (_tv.running) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
          // auto-complete check
          if (_tv.isComplete && _tv.running) {
            // auto-pause when done
            _pauseInternal(auto: true);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _persist(TimerValue v) async {
    setState(() => _tv = v);
    _startTickerIfNeeded();
    await ref.read(supabaseServiceProvider).setCellValue(widget.taskId, widget.date, widget.columnId, v.toJson());
  }

  void _pauseInternal({bool auto = false}) {
    final now = DateTime.now();
    final paused = _tv.paused(now);
    _persist(paused);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(entriesProvider);

    final eff = _tv.effectiveElapsed(DateTime.now());
    final remaining = _tv.remainingSec;
    final progress = _tv.progress;
    final isRunning = _tv.running;
    final isDone = _tv.isComplete;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
      title: Row(children: [
        const Icon(Icons.hourglass_bottom_rounded, size: 18, color: AppColors.accent),
        const SizedBox(width: 8),
        const Text('Timer', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
          tooltip: 'Edit duration',
          onPressed: () async {
            final ctrl = TextEditingController(text: TimerValue.formatSec(_tv.durationSec));
            final res = await showDialog<String>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
                title: const Text('Edit duration', style: TextStyle(color: AppColors.textPrimary)),
                content: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Duration')),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Save'))],
              ),
            );
            if (res != null && res.trim().isNotEmpty) {
              final sec = TimerValue.parseDurationToSec(res.trim());
              if (sec > 0) {
                final updated = TimerValue(durationSec: sec, elapsedSec: 0, running: false);
                await _persist(updated);
              }
            }
          },
        ),
      ]),
      content: SizedBox(
        width: 320,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            height: 14,
            decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)),
            clipBehavior: Clip.antiAlias,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(color: isDone ? AppColors.doneBorder : AppColors.accent),
            ),
          ),
          const SizedBox(height: 16),
          Text(TimerValue.formatSec(remaining), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: isDone ? AppColors.doneText : AppColors.textPrimary)),
          Text(isRunning ? 'remaining' : (isDone ? 'completed' : 'paused'), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Text('${TimerValue.formatSec(eff)} elapsed / ${TimerValue.formatSec(_tv.durationSec)} total', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            if (!isRunning && !isDone)
              FilledButton.icon(onPressed: remaining == _tv.durationSec ? () => _persist(_tv.started(DateTime.now())) : () => _persist(_tv.started(DateTime.now())), icon: const Icon(Icons.play_arrow, size: 16), label: Text(remaining == _tv.durationSec ? 'Start' : 'Resume')),
            if (isRunning) FilledButton.icon(onPressed: () => _persist(_tv.paused(DateTime.now())), icon: const Icon(Icons.pause, size: 16), label: const Text('Pause'), style: FilledButton.styleFrom(backgroundColor: AppColors.inputFill, foregroundColor: AppColors.textPrimary, side: const BorderSide(color: AppColors.border))),
            FilledButton.icon(onPressed: () => _persist(_tv.stopped()), icon: const Icon(Icons.stop, size: 16), label: const Text('Stop'), style: FilledButton.styleFrom(backgroundColor: AppColors.cancelFill, foregroundColor: AppColors.cancelText, side: const BorderSide(color: AppColors.cancelBorder))),
            FilledButton.icon(onPressed: () => _persist(_tv.restarted(DateTime.now())), icon: const Icon(Icons.restart_alt, size: 16), label: const Text('Restart')),
          ]),
          if (isDone) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.doneFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.doneBorder)), child: const Text('Completed', style: TextStyle(color: AppColors.doneText, fontSize: 11, fontWeight: FontWeight.w700))),
          ]
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
