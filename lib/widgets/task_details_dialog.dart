import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';

import '../config/app_colors.dart';
import '../models/column_definition.dart';
import '../models/enums.dart';
import '../models/task.dart';
import '../providers/app_providers.dart';
import '../services/supabase_service.dart';
import 'cells/cell_widgets.dart';
import 'reminder_dialog.dart';
import 'day_detail_panel.dart';

/// Everything you can do to a task, in one place.
///
/// Reached by clicking the task name in Weekly. The row used to carry a "..."
/// menu, but a 30px icon button ate a third of a 160px name column and the
/// options were two taps deep anyway; clicking the name is both bigger and
/// one tap shorter.
Future<void> showTaskDetails(
  BuildContext context, {
  required Task task,
  required List<DateTime> weekDays,
  void Function()? onRenamed,
  void Function()? onNotesRecap,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.border)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: _TaskDetailsBody(
          taskId: task.id,
          weekDays: weekDays,
          // The caller's context, not the dialog's: anything that opens after
          // this dialog closes has to be pushed onto a context that is still
          // mounted.
          hostContext: context,
          onRenamed: onRenamed,
          onNotesRecap: onNotesRecap,
        ),
      ),
    ),
  );
}

class _TaskDetailsBody extends ConsumerStatefulWidget {
  final String taskId;
  final List<DateTime> weekDays;

  /// A context from the widget that opened this dialog. Used for anything that
  /// has to be shown *after* this dialog closes.
  final BuildContext hostContext;
  final void Function()? onRenamed;
  final void Function()? onNotesRecap;
  const _TaskDetailsBody({
    required this.taskId,
    required this.weekDays,
    required this.hostContext,
    this.onRenamed,
    this.onNotesRecap,
  });
  @override
  ConsumerState<_TaskDetailsBody> createState() => _TaskDetailsBodyState();
}

class _TaskDetailsBodyState extends ConsumerState<_TaskDetailsBody> {
  late Task _task;

  @override
  void initState() {
    super.initState();
    // Re-read on every build of the dialog: renaming elsewhere, or a tag
    // created in the picker, should show up here straight away.
    _task = ref.read(supabaseServiceProvider).taskById(widget.taskId) ??
        Task(id: widget.taskId, name: '', position: 0, createdAt: DateTime.now(), userId: '');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final svc = ref.read(supabaseServiceProvider);
    ref.watch(tasksProvider);
    final t = svc.taskById(widget.taskId);
    if (t != null) _task = t;

    final tagCol = svc.columns.where((c) => c.type == ColumnType.tags).firstOrNull;
    final tagOptions = tagCol?.tagOptions ?? const <TagOption>[];
    final myTags = _task.tags
        .map((id) => tagOptions.where((o) => o.id == id).firstOrNull ?? TagOption(id: id, label: id))
        .toList();
    final assignedDays = widget.weekDays.where((d) {
      final e = svc.entryFor(_task.id, d);
      return e != null && svc.isAssigned(e);
    }).toList();

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header: name, with rename in place.
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
        child: Row(children: [
          Expanded(
            child: InkWell(
              onTap: () => _rename(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(children: [
                  Flexible(
                    child: Text(
                      _task.name.isEmpty ? loc.untitledCap : _task.name,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_outlined, size: 13, color: AppColors.textSecondary),
                ]),
              ),
            ),
          ),
          IconButton(icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
        ]),
      ),

      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Tags on the task itself.
            _sectionLabel(context, loc.taskTagsTitle),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tag in myTags)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tag.hasColor ? _hex(tag.colorHex).withValues(alpha: 0.18) : AppColors.inputFill,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tag.hasColor ? _hex(tag.colorHex) : AppColors.border),
                    ),
                    child: Text(tag.label, style: TextStyle(fontSize: 11.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  ),
                // Tap to add or remove; the picker also creates new tags.
                InkWell(
                  onTap: () => _editTags(context, tagCol),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(myTags.isEmpty ? loc.addTaskTags : loc.editTaskTags, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    ]),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            _sectionLabel(context, loc.weekDaysTitle),
            if (assignedDays.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(loc.notScheduledShort, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in assignedDays)
                    InkWell(
                      onTap: () => _closeThen(context, () => showDayDetail(widget.hostContext, d)),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(_weekday(d), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textSecondary),
                        ]),
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 16),
            _sectionLabel(context, loc.setReminderItem),
            InkWell(
              onTap: () => _closeThen(context, () => showReminderDialog(widget.hostContext, _task)),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  Icon(Icons.notifications_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (_task.reminder ?? '').isEmpty ? loc.setReminderItem : loc.reminderSet((_task.reminder as String).toUpperCase()),
                      style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textSecondary),
                ]),
              ),
            ),
          ]),
        ),
      ),

      // Destructive action last, so it is never one mis-tap away.
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        child: Row(children: [
          if (widget.onNotesRecap != null)
            TextButton.icon(
              onPressed: () {
                final cb = widget.onNotesRecap!;
                // Open it from the host context, and only after this dialog is
                // gone: showDialog pushes a route, so a pop straight after the
                // push would close the recap again and the button would do
                // nothing at all.
                _closeThen(context, cb);
              },
              icon: const Icon(Icons.notes_rounded, size: 15),
              label: Text(loc.notesRecap, style: const TextStyle(fontSize: 12.5)),
            ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              svc.deleteTask(_task.id);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: Text(loc.delete, style: const TextStyle(fontSize: 12.5)),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF43F5E)),
          ),
        ]),
      ),
    ]);
  }

  /// Closes this dialog and only then runs [then].
  ///
  /// The order matters and getting it wrong is invisible: a callback that
  /// opens its own dialog pushes a route on top, so popping straight afterwards
  /// closed *that* one instead of this one and nothing appeared to happen. The
  /// same trap applies to opening anything with this dialog's own `context`,
  /// which is unmounted by the time the pop finishes.
  Future<void> _closeThen(BuildContext dialogContext, void Function() then) async {
    Navigator.pop(dialogContext);
    // Wait for the dialog's exit animation. Pushing the next route on the same
    // frame the old one leaves looks like nothing happened at all.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    then();
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3)),
      );

  Future<void> _rename(BuildContext context) async {
    final svc = ref.read(supabaseServiceProvider);
    final loc = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: _task.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
        title: Text(loc.rename, style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 340,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(labelText: loc.labelFieldLbl),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: Text(loc.save)),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null) return;
    await svc.updateTask(_task.copyWith(name: name.trim().isEmpty ? _task.name : name.trim()));
    widget.onRenamed?.call();
    if (mounted) setState(() {});
  }

  Future<void> _editTags(BuildContext context, ColumnDefinition? tagCol) async {
    final svc = ref.read(supabaseServiceProvider);
    final res = await showDialog<({List<String> selected, List<TagOption> options})>(
      context: context,
      builder: (_) => TagPickerDialog(options: tagCol?.tagOptions ?? const [], selected: _task.tags),
    );
    if (res == null) return;
    // A tag created here has to be written back to the column, or it is only
    // alive in this dialog and gone after the next column fetch.
    if (tagCol != null && !listEquals(res.options, tagCol.tagOptions)) {
      await svc.updateColumn(ColumnDefinition(
        id: tagCol.id,
        label: tagCol.label,
        type: tagCol.type,
        position: tagCol.position,
        config: {...tagCol.config, 'options': res.options.map((e) => e.toJson()).toList()},
        visibleDays: tagCol.visibleDays,
      ));
    }
    await svc.setTaskTags(_task.id, res.selected);
    if (mounted) setState(() {});
  }

  static String _weekday(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${names[d.weekday - 1]} ${d.day}';
  }
}

Color _hex(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.isEmpty) h = TagOption.neutralColorHex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.tryParse(h, radix: 16) ?? 0xFF64748B);
}
