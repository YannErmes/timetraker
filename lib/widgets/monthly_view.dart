import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/app_providers.dart';
import '../providers/task_filters.dart';
import '../utils/date_utils.dart';
import '../models/enums.dart';
import '../services/google_calendar_service.dart';
import 'day_detail_panel.dart';
import 'cells/cell_widgets.dart';
import 'cells/timer_cell.dart';
import '../models/timer_value.dart';

class MonthlyView extends ConsumerStatefulWidget {
  const MonthlyView({super.key});
  @override
  ConsumerState<MonthlyView> createState() => _MonthlyViewState();
}

class _MonthlyViewState extends ConsumerState<MonthlyView> {
  Timer? _flashTimer;
  bool _flashToday = false;
  final _todayKey = GlobalKey();

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  /// Jump to the current month, scroll today's cell into view and flash it.
  void _goToday() {
    ref.read(selectedDateProvider.notifier).state = DateTime.now();
    _flashTimer?.cancel();
    setState(() => _flashToday = true);
    _flashTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _flashToday = false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _todayKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut, alignment: 0.35);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(supabaseServiceProvider);
    ref.watch(tasksProvider);
    ref.watch(entriesProvider);
    final tasks = svc.tasks;
    final entries = svc.entries;
    final anchor = ref.watch(selectedDateProvider);
    final days = monthDates(anchor);
    final monthLabel = '${_monthName(anchor.month)} ${anchor.year}';
    // Row index (0-5) of the week containing today, if today is visible in
    // this 42-day grid — used to slightly highlight the current week row.
    final todayNorm = normalizeDate(DateTime.now());
    int? currentWeekRow;
    for (int k = 0; k < days.length; k++) {
      if (normalizeDate(days[k]) == todayNorm) {
        currentWeekRow = k ~/ 7;
        break;
      }
    }
    return Container(
      color: AppColors.bg,
      child: Column(children: [
        Container(
          color: AppColors.header,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary), onPressed: () => ref.read(selectedDateProvider.notifier).state = DateTime(anchor.year, anchor.month - 1, 1)),
            Text(monthLabel, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary), onPressed: () => ref.read(selectedDateProvider.notifier).state = DateTime(anchor.year, anchor.month + 1, 1)),
            const Spacer(),
            OutlinedButton(onPressed: _goToday, child: const Text('Today')),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.sync_rounded, size: 18, color: AppColors.textSecondary),
              tooltip: 'Sync monthly to Google',
              onPressed: () async {
                try {
                  final svc = ref.read(supabaseServiceProvider);
                  final count = await GoogleCalendarService.instance.syncMonth(anchor, svc.tasks, svc.entries);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Synced $count events to Google Calendar'), backgroundColor: AppColors.surface));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e. Connect Google first in View Settings (tune icon).')));
                }
              },
            ),
            const SizedBox(width: 4),
            FilledButton.icon(icon: const Icon(Icons.add, size: 16), label: const Text('Add task'), onPressed: () => _showAddTaskDialog(context, ref, anchor)),
          ]),
        ),
        Container(
          color: AppColors.header,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((w) => Expanded(child: Center(child: Text(w, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary))))).toList()),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.92, crossAxisSpacing: 6, mainAxisSpacing: 6),
            itemCount: days.length,
            itemBuilder: (_, i) {
              final d = days[i];
              final isCurrentMonth = d.month == anchor.month;
              final isToday = normalizeDate(d) == normalizeDate(DateTime.now());
              final isCurrentWeek = currentWeekRow != null && (i ~/ 7) == currentWeekRow;
              // Checkbox = scheduled: only checked entries are considered scheduled for this day
              final allScheduled = entries.where((e) => e.dateKey == _key(d) && e.checked).toList();
              // apply global task filters to scheduled entries for this day
              final filters = ref.watch(taskFiltersProvider);
              final cols = ref.watch(supabaseServiceProvider).columns;
              final scheduledEntries = allScheduled.where((e) {
                final task = tasks.where((t) => t.id == e.taskId).firstOrNull;
                if (task == null) return false;
                if (filters.search.isNotEmpty && !task.name.toLowerCase().contains(filters.search.toLowerCase())) return false;
                if (filters.status != null) {
                  final statusCol = cols.where((c) => c.type.name == 'status').firstOrNull;
                  if (statusCol == null) return false;
                  if ((e.data[statusCol.id] as String?) != filters.status) return false;
                }
                if (filters.hasNoteOnly) {
                  final noteCol = cols.where((c) => c.id == 'col_note').firstOrNull;
                  if (noteCol == null) return false;
                  final note = e.data[noteCol.id] as String?;
                  if (note == null || note.trim().isEmpty) return false;
                }
                if (filters.tag != null) {
                  final hasTag = e.data.values.any((v) => v is List && (v as List).contains(filters.tag));
                  if (!hasTag) return false;
                }
                return true;
              }).toList();
              final total = tasks.isEmpty ? 1 : tasks.length;
              final scheduled = scheduledEntries.length;
              final pct = (scheduled / total).toDouble();
              final heat = _heatColor(pct);
              // Base fill per today/current-month, with a slight accent wash
              // across the whole current-week row so it reads as one band.
              final baseFill = isToday
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : isCurrentMonth
                      ? AppColors.surface
                      : AppColors.surface.withValues(alpha: 0.6);
              final cellFill = (isCurrentWeek && !isToday)
                  ? Color.alphaBlend(AppColors.accent.withValues(alpha: 0.08), baseFill)
                  : baseFill;
              final cellBorder = isToday
                  ? AppColors.accent
                  : (isCurrentWeek ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border);
              // Brief flash-boost right after tapping Today.
              final boosting = isToday && _flashToday;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  ref.read(selectedDateProvider.notifier).state = d;
                  showDayDetail(context, d);
                },
                child: Container(
                  key: isToday ? _todayKey : null,
                  decoration: BoxDecoration(
                    color: boosting ? AppColors.accent.withValues(alpha: 0.32) : cellFill,
                    border: Border.all(color: cellBorder, width: isToday ? (boosting ? 3 : 2) : 1),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: boosting ? 0.55 : 0.28),
                              blurRadius: boosting ? 18 : 10,
                              spreadRadius: boosting ? 3 : 1,
                            )
                          ]
                        : null,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: isToday ? AppColors.accent : Colors.transparent, shape: BoxShape.circle),
                        child: Text('${d.day}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isToday ? Colors.white : isCurrentMonth ? AppColors.textPrimary : AppColors.textSecondary)),
                      ),
                      const Spacer(),
                      if (scheduledEntries.isNotEmpty) Container(width: 10, height: 10, decoration: BoxDecoration(color: heat, shape: BoxShape.circle)),
                    ]),
                    const SizedBox(height: 4),
                    Text('$scheduled/$total scheduled', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: pct, minHeight: 4, backgroundColor: AppColors.inputFill, valueColor: AlwaysStoppedAnimation(heat), borderRadius: BorderRadius.circular(8)),
                    if (scheduledEntries.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Expanded(
                        child: ListView(
                          physics: const NeverScrollableScrollPhysics(),
                          children: scheduledEntries.take(3).map((e) {
                            final t = tasks.where((x) => x.id == e.taskId).firstOrNull;
                            return Text(t == null ? '' : (t.name.isEmpty ? '·' : t.name), style: const TextStyle(fontSize: 9, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis);
                          }).toList(),
                        ),
                      ),
                    ]
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref, DateTime anchor) {
    final sel = ref.read(selectedDateProvider);
    final isInMonth = sel.year == anchor.year && sel.month == anchor.month;
    final useDate = isInMonth ? sel : DateTime(anchor.year, anchor.month, 15);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
          child: _MonthlyAddTaskDialog(initialDate: useDate),
        ),
      ),
    );
  }

  String _key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _monthName(int m) => ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
  Color _heatColor(double pct) {
    if (pct == 0) return AppColors.border;
    if (pct < 0.3) return const Color(0xFFF59E0B);
    if (pct < 0.7) return const Color(0xFF22C55E).withValues(alpha: 0.7);
    return const Color(0xFF22C55E);
  }
}

class _MonthlyAddTaskDialog extends ConsumerStatefulWidget {
  final DateTime initialDate;
  const _MonthlyAddTaskDialog({required this.initialDate});
  @override
  ConsumerState<_MonthlyAddTaskDialog> createState() => _MonthlyAddTaskDialogState();
}

class _MonthlyAddTaskDialogState extends ConsumerState<_MonthlyAddTaskDialog> {
  late DateTime _date;
  final _nameCtrl = TextEditingController();
  String? _schedule; // HH:mm
  String _durationText = '';
  String? _status = 'none';
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(supabaseServiceProvider);
    final cols = svc.columns;
    final statusCol = cols.where((c) => c.type.name == 'status').firstOrNull;
    final statusOpts = statusCol != null ? (statusCol.config['options'] as List? ?? []) : [];

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(color: AppColors.header, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            const Icon(Icons.add_task_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            const Text('Add task', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: _nameCtrl, autofocus: true, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Task name *', hintText: 'e.g. Typing')),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2035));
                  if (d != null) setState(() => _date = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    const Text('Scheduled day:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Text(_fmtDate(_date), style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textSecondary),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              // Schedule time-of-day
              Row(children: [
                const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                const Text('Schedule', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (t != null) setState(() => _schedule = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                  },
                  child: Text(_schedule == null ? 'Set time' : _schedule!, style: const TextStyle(fontSize: 12)),
                ),
                if (_schedule != null) IconButton(icon: const Icon(Icons.clear, size: 14), onPressed: () => setState(() => _schedule = null)),
              ]),
              const SizedBox(height: 8),
              // Time duration
              TextField(
                onChanged: (v) => _durationText = v,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                decoration: const InputDecoration(labelText: 'Time (duration)', hintText: 'e.g. 3h5min, 4h, 30min', prefixIcon: Icon(Icons.hourglass_bottom_rounded, size: 16)),
              ),
              const SizedBox(height: 12),
              // Status
              DropdownButtonFormField<String?>(
                value: _status,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                decoration: const InputDecoration(labelText: 'Status', isDense: true),
                items: [
                  for (final o in statusOpts)
                    DropdownMenuItem(value: (o as Map<String, dynamic>)['id'] as String, child: Text((o as Map<String, dynamic>)['label'] as String)),
                  if (statusOpts.isEmpty) const DropdownMenuItem(value: 'none', child: Text('none')),
                ],
                onChanged: (v) => setState(() => _status = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                maxLines: 3,
                minLines: 2,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                decoration: const InputDecoration(labelText: 'Note', hintText: 'Add a note for this task…'),
              ),
            ]),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border)), borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
          child: Row(children: [
            const Expanded(child: Text('Creates task and schedules it for the chosen day (checkbox = scheduled).', style: TextStyle(fontSize: 10, color: AppColors.textSecondary))),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                final name = _nameCtrl.text.trim();
                if (name.isEmpty) return;
                final svc = ref.read(supabaseServiceProvider);
                // create task
                await svc.addTask(name);
                // find newly created task (last by position)
                await Future.delayed(const Duration(milliseconds: 100));
                final tasks = svc.tasks;
                final created = tasks.where((t) => t.name == name).toList().isNotEmpty ? tasks.lastWhere((t) => t.name == name) : tasks.last;
                // build per-day data
                final data = <String, dynamic>{};
                // find column ids
                final cols = svc.columns;
                String? scheduleId;
                String? timeId;
                String? statusId;
                String? noteId;
                for (final c in cols) {
                  if (c.id == 'col_schedule' || (c.type.name == 'schedule')) scheduleId = c.id;
                  if (c.id == 'col_time' || c.type.name == 'timer') timeId = c.id;
                  if (c.type.name == 'status') statusId = c.id;
                  if (c.id == 'col_note') noteId = c.id;
                }
                if (scheduleId != null && _schedule != null) data[scheduleId] = _schedule;
                if (timeId != null && _durationText.trim().isNotEmpty) {
                  final sec = TimerValue.parseDurationToSec(_durationText.trim());
                  if (sec > 0) data[timeId] = TimerValue(durationSec: sec).toJson();
                }
                if (statusId != null && _status != null) data[statusId] = _status;
                if (noteId != null && _noteCtrl.text.trim().isNotEmpty) data[noteId] = _noteCtrl.text.trim();
                // schedule by checking box
                await svc.toggleChecked(created.id, _date, true);
                if (data.isNotEmpty) {
                  for (final e in data.entries) {
                    await svc.setCellValue(created.id, _date, e.key, e.value);
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ]),
        ),
      ]),
    );
  }
}
