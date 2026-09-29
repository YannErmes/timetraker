import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../../config/app_colors.dart';
import '../../models/column_definition.dart';
import '../../models/timer_value.dart';
import '../../providers/app_providers.dart';
import 'cell_widgets.dart';
import 'timer_cell.dart';

/// Opens the full cell editor in a dialog (used by Basic icon cells).
Future<void> showCellEditorDialog(BuildContext context, {required String title, required Widget editor}) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
      title: Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
      content: SizedBox(width: 340, child: editor),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );
}

Color _hex(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

/// The status id a cell should actually show, and its label and colour.
///
/// One resolution for all three, so they can never disagree. They used to be
/// worked out separately - the label from `valueId ?? idle` but the colour
/// from `valueId ?? none` - which is why an unassigned cell showed the word
/// "idle" in the purple that belongs to "none".
({String id, String label, Color color}) resolveStatus(String? valueId, List<StatusOption> options) {
  final ids = options.map((o) => o.id).toSet();
  // Unassigned reads as "idle" when the column has it, then "none", then
  // whatever the first option is. An id that is no longer in the column falls
  // back the same way instead of rendering a stale value.
  final fallback = ids.contains('idle')
      ? 'idle'
      : ids.contains('none')
          ? 'none'
          : (options.isNotEmpty ? options.first.id : '');
  final id = (valueId != null && ids.contains(valueId)) ? valueId : fallback;
  String label = id;
  for (final o in options) {
    if (o.id == id) {
      label = o.label;
      break;
    }
  }
  return (id: id, label: label, color: statusDotColor(id, options));
}

/// Status dot color for a value id, falling back to known pills.
///
/// There is no colour per status built into the app: a status the customer
/// never coloured gets the neutral grey, so nothing shows a colour that
/// belongs to a different status. The switch only covers ids that are no
/// longer in the column at all (a value left over from a deleted option).
Color statusDotColor(String? valueId, List<StatusOption> options) {
  final id = valueId ?? 'none';
  for (final o in options) {
    if (o.id == id) return _hex(o.effectiveColorHex);
  }
  switch (id) {
    case 'done':
      return const Color(0xFF22C55E);
    case 'cancel':
      return const Color(0xFFF43F5E);
    case 'in_progress':
    case 'in progress':
      return const Color(0xFFF59E0B);
    default:
      return _hex(StatusOption.neutralColor);
  }
}

/// Basic view: icon-only timer cell. Tap opens the full timer editor.
class CompactTimerIcon extends ConsumerWidget {
  final String taskId;
  final DateTime date;
  final String columnId;
  final dynamic rawValue;
  final String title;
  const CompactTimerIcon({super.key, required this.taskId, required this.date, required this.columnId, required this.rawValue, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final tv = TimerValue.tryParse(rawValue);
    final has = tv != null && tv.durationSec > 0;
    final tooltip = has ? TimerValue.formatSec(tv.durationSec) : loc.setDurationBtn;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showCellEditorDialog(
          context,
          title: title,
          editor: TimerCell(taskId: taskId, date: date, columnId: columnId, rawValue: rawValue),
        ),
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: has ? AppColors.accent.withValues(alpha: 0.6) : AppColors.inputBorder),
          ),
          child: Center(
            child: Icon(
              has ? (tv.running ? Icons.hourglass_bottom_rounded : Icons.hourglass_empty_rounded) : Icons.hourglass_empty_rounded,
              size: 16,
              color: has ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Basic view: icon-only status cell. Tap opens the full status editor.
class CompactStatusIcon extends ConsumerWidget {
  final String taskId;
  final DateTime date;
  final ColumnDefinition col;
  final dynamic rawValue;
  final String title;
  const CompactStatusIcon({super.key, required this.taskId, required this.date, required this.col, required this.rawValue, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valueId = rawValue as String?;
    final st = resolveStatus(valueId, col.statusOptions);
    final dot = st.color;
    final label = st.label;
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showCellEditorDialog(
          context,
          title: title,
          editor: StatusCell(
            valueId: valueId,
            options: col.statusOptions,
            onChanged: (v) => ref.read(supabaseServiceProvider).setCellValue(taskId, date, col.id, v),
          ),
        ),
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Center(child: Icon(Icons.circle, size: 14, color: dot)),
        ),
      ),
    );
  }
}

/// Soft status chip for the weekly grid: a tinted background and the status
/// word, with no border and no dropdown arrow. Tapping opens the full editor.
/// Users reported the bordered dropdown cells as far too high-contrast, so the
/// weekly grid reads as a calm table instead of a wall of boxes.
class SoftStatusPill extends ConsumerWidget {
  final String taskId;
  final DateTime date;
  final ColumnDefinition col;
  final dynamic rawValue;
  final String title;
  const SoftStatusPill({super.key, required this.taskId, required this.date, required this.col, required this.rawValue, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valueId = rawValue as String?;
    final st = resolveStatus(valueId, col.statusOptions);
    final dot = st.color;
    final label = st.label;
    return Tooltip(
      message: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () => showCellEditorDialog(
          context,
          title: title,
          editor: StatusCell(
            valueId: valueId,
            options: col.statusOptions,
            onChanged: (v) => ref.read(supabaseServiceProvider).setCellValue(taskId, date, col.id, v),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: dot.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(7)),
          child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: dot), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

/// 32px status dot button (replaces the scheduling checkbox).
/// Tap opens the full status editor; idle means unassigned for the day.
class StatusDotButton extends ConsumerWidget {
  final String taskId;
  final DateTime date;
  final ColumnDefinition col;
  final dynamic rawValue;
  final String title;
  const StatusDotButton({super.key, required this.taskId, required this.date, required this.col, required this.rawValue, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final valueId = rawValue as String?;
    final st = resolveStatus(valueId, col.statusOptions);
    final dot = st.color;
    final assigned = st.id != 'idle' && st.id != 'none';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showCellEditorDialog(
        context,
        title: title,
        editor: StatusCell(
          valueId: valueId,
          options: col.statusOptions,
          onChanged: (v) => ref.read(supabaseServiceProvider).setCellValue(taskId, date, col.id, v),
        ),
      ),
      child: Tooltip(
        message: t.statusTip,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: assigned ? dot.withValues(alpha: 0.16) : AppColors.inputFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: assigned ? dot : AppColors.inputBorder, width: assigned ? 1.5 : 1),
          ),
          child: Icon(Icons.circle, size: 12, color: dot),
        ),
      ),
    );
  }
}
