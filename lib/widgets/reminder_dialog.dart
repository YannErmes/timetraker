import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../models/task.dart';
import '../providers/app_providers.dart';

/// Reminder editor: free shorthand field (10MI, 2H, 1D, 1W, 1M).
/// Empty clears the reminder.
class ReminderDialog extends ConsumerStatefulWidget {
  final Task task;
  const ReminderDialog({super.key, required this.task});
  @override
  ConsumerState<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends ConsumerState<ReminderDialog> {
  late final TextEditingController _ctrl;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.task.reminder ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context)!;
    final raw = _ctrl.text.trim();
    if (raw.isNotEmpty && Task.parseReminder(raw) == null) {
      setState(() => _error = t.reminderInvalid);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final svc = ref.read(supabaseServiceProvider);
      await svc.updateTask(widget.task.copyWith(reminder: () => raw.isEmpty ? null : raw.toUpperCase()));
      svc.refreshTaskReminders();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        Text(t.reminderTitle, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
      ]),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(labelText: t.reminderTitle, hintText: t.reminderHint),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Text(t.reminderUnitsHelp, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 12)),
          ],
        ]),
      ),
      actions: [
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

Future<void> showReminderDialog(BuildContext context, Task task) {
  return showDialog(context: context, builder: (_) => ReminderDialog(task: task));
}
