import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../../config/app_colors.dart';
import '../../providers/app_providers.dart';

/// Compact reminder cell: bell + date/time + message snippet.
/// Tap opens the full day/time/message editor.
class ReminderCell extends ConsumerWidget {
  final String taskId;
  final DateTime date;
  final String columnId;
  final dynamic rawValue; // {'fireAt': iso, 'message': text} or null
  const ReminderCell({super.key, required this.taskId, required this.date, required this.columnId, required this.rawValue});

  static DateTime? fireAtOf(dynamic raw) {
    if (raw is! Map) return null;
    return DateTime.tryParse(raw['fireAt'] as String? ?? '');
  }

  static String messageOf(dynamic raw) {
    if (raw is! Map) return '';
    return (raw['message'] as String? ?? '').trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final when = fireAtOf(rawValue);
    final msg = messageOf(rawValue);
    final has = when != null;
    final label = has
        ? '${when.month}/${when.day} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}'
        : t.remEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showReminderCellDialog(context, taskId: taskId, date: date, columnId: columnId, rawValue: rawValue),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: has ? AppColors.accent.withValues(alpha: 0.6) : AppColors.inputBorder),
        ),
        child: Row(children: [
          Icon(has ? Icons.notifications_active_outlined : Icons.notifications_outlined, size: 13, color: has ? AppColors.accent : AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(has && msg.isNotEmpty ? '$label · $msg' : label,
                style: TextStyle(fontSize: 11, color: has ? AppColors.textPrimary : AppColors.textSecondary, fontStyle: has ? FontStyle.normal : FontStyle.italic),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
        ]),
      ),
    );
  }
}

/// Full reminder editor: pick a day, a time, write the message, save.
/// Saving writes the cell AND queues the email + app notification.
Future<void> showReminderCellDialog(BuildContext context,
    {required String taskId, required DateTime date, required String columnId, required dynamic rawValue}) async {
  final current = ReminderCell.fireAtOf(rawValue);
  DateTime day = DateTime(date.year, date.month, date.day);
  TimeOfDay time = current != null ? TimeOfDay(hour: current.hour, minute: current.minute) : const TimeOfDay(hour: 9, minute: 0);
  final msgCtrl = TextEditingController(text: ReminderCell.messageOf(rawValue));
  await showDialog(
    context: context,
    builder: (ctx) => _ReminderEditDialog(taskId: taskId, day: day, time: time, columnId: columnId, msgCtrl: msgCtrl),
  );
  msgCtrl.dispose();
}

class _ReminderEditDialog extends ConsumerStatefulWidget {
  final String taskId;
  final DateTime day;
  final TimeOfDay time;
  final String columnId;
  final TextEditingController msgCtrl;
  const _ReminderEditDialog({required this.taskId, required this.day, required this.time, required this.columnId, required this.msgCtrl});
  @override
  ConsumerState<_ReminderEditDialog> createState() => _ReminderEditDialogState();
}

class _ReminderEditDialogState extends ConsumerState<_ReminderEditDialog> {
  late DateTime _day;
  late TimeOfDay _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _day = widget.day;
    _time = widget.time;
  }

  String _fmtDay(DateTime d) => '${d.month}/${d.day}/${d.year}';

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final when = DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);
      await ref.read(supabaseServiceProvider).setReminderCell(
            taskId: widget.taskId,
            date: _day,
            columnId: widget.columnId,
            when: when,
            message: widget.msgCtrl.text,
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    await ref.read(supabaseServiceProvider).setReminderCell(
          taskId: widget.taskId,
          date: _day,
          columnId: widget.columnId,
          when: null,
          message: null,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border)),
      title: Row(children: [
        Icon(Icons.notifications_outlined, size: 18, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(t.remCellTitle, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
      ]),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.remDateLbl, style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (d != null) setState(() => _day = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(_fmtDay(_day), style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.remTimeLbl, style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _time);
                    if (picked != null) setState(() => _time = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)),
                    child: Row(children: [
                      Icon(Icons.access_time_rounded, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(_time.format(context), style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: widget.msgCtrl,
            maxLines: 3,
            minLines: 2,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: InputDecoration(labelText: t.remMsgLbl, hintText: t.remMsgHint, alignLabelWithHint: true),
          ),
          const SizedBox(height: 8),
          Text(t.remSavedTip, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ]),
      ),
      actions: [
        TextButton(onPressed: _clear, child: Text(t.remClearBtn)),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded, size: 14),
          label: Text(t.save),
        ),
      ],
    );
  }
}
