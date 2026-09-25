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

/// Status dot color for a value id, falling back to known pills.
Color statusDotColor(String? valueId, List<StatusOption> options) {
  final id = valueId ?? 'none';
  try {
    final opt = options.firstWhere((o) => o.id == id);
    return _hex(opt.colorHex);
  } catch (_) {}
  switch (id) {
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
    final dot = statusDotColor(valueId, col.statusOptions);
    final fallbackId = col.statusOptions.any((o) => o.id == 'idle') ? 'idle' : 'none';
    final label = (() {
      try {
        return col.statusOptions.firstWhere((o) => o.id == (valueId ?? fallbackId)).label;
      } catch (_) {
        return valueId ?? fallbackId;
      }
    })();
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
    final dot = statusDotColor(valueId, col.statusOptions);
    final assigned = valueId != null && valueId != 'idle';
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
