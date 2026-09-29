import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../../config/app_colors.dart';
import '../../models/column_definition.dart';
import '../../providers/app_providers.dart';
import '../column_settings_panel.dart' show ColorPickerDialog;

Color _hex(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

// Pill colors per spec — maps option id to fill/text/border
class _PillStyle {
  final Color fill;
  final Color text;
  final Color border;
  const _PillStyle({required this.fill, required this.text, required this.border});
}

_PillStyle _pillFor(String? id) {
  switch (id) {
    case 'done':
      return _PillStyle(fill: AppColors.doneFill, text: AppColors.doneText, border: AppColors.doneBorder);
    case 'cancel':
      return _PillStyle(fill: AppColors.cancelFill, text: AppColors.cancelText, border: AppColors.cancelBorder);
    case 'in_progress':
    case 'in progress':
      return _PillStyle(fill: AppColors.inProgressFill, text: AppColors.inProgressText, border: AppColors.inProgressBorder);
    case 'none':
      return _PillStyle(fill: AppColors.purpleFill, text: AppColors.purpleText, border: AppColors.purpleBorder);
    case 'idle':
    default:
      // idle / unset = quiet slate, low contrast
      return _PillStyle(fill: AppColors.inputFill, text: AppColors.textSecondary, border: AppColors.inputBorder);
  }
}

class StatusCell extends StatefulWidget {
  final String? valueId;
  final List<StatusOption> options;
  final ValueChanged<String?> onChanged;
  const StatusCell({super.key, required this.valueId, required this.options, required this.onChanged});
  @override
  State<StatusCell> createState() => _StatusCellState();
}

class _StatusCellState extends State<StatusCell> {
  bool _focused = false;

  /// Options guaranteed to contain an 'idle' entry so unassigning is
  /// always possible, even for columns created before idle existed.
  List<StatusOption> get _effectiveOptions {
    if (widget.options.any((o) => o.id == 'idle')) return widget.options;
    return [const StatusOption(id: 'idle', label: 'idle'), ...widget.options];
  }

  @override
  Widget build(BuildContext context) {
    final ids = _effectiveOptions.map((o) => o.id).toSet();
    // Default to idle (unassigned); fall back to a valid option so the
    // dropdown value always matches an item.
    String effectiveId = widget.valueId ?? 'idle';
    if (!ids.contains(effectiveId)) {
      effectiveId = ids.contains('none') ? 'none' : _effectiveOptions.first.id;
    }
    final pill = _pillFor(effectiveId);
    final isSet = effectiveId != 'none' && effectiveId != 'idle';
    // If custom options, fall back to hex if not one of known ids
    Color fill = pill.fill;
    Color text = pill.text;
    Color border = pill.border;
    if (isSet && effectiveId != 'done' && effectiveId != 'cancel' && effectiveId != 'in_progress' && effectiveId != 'in progress') {
      try {
        final opt = widget.options.firstWhere((o) => o.id == effectiveId);
        // use custom hex as border, derive muted fill
        border = _hex(opt.effectiveColorHex);
        fill = border.withValues(alpha: 0.18);
        text = Colors.white;
      } catch (_) {}
    }
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _focused ? AppColors.accent : border, width: _focused ? 2 : 1),
          boxShadow: _focused ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 0, spreadRadius: 1)] : null,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: effectiveId,
            isExpanded: true,
            isDense: true,
            icon: Icon(Icons.arrow_drop_down, size: 18, color: isSet ? text.withValues(alpha: 0.9) : AppColors.textSecondary),
            style: TextStyle(fontSize: 12, color: isSet ? text : AppColors.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.2),
            dropdownColor: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            items: [
              for (final o in _effectiveOptions)
                DropdownMenuItem(
                  value: o.id,
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: _pillFor(o.id).border, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(o.label, style: TextStyle(color: o.id == 'none' || o.id == 'idle' ? AppColors.textSecondary : AppColors.textPrimary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ]),
                ),
            ],
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
  }
}

class DurationCell extends StatefulWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const DurationCell({super.key, required this.value, required this.onChanged});
  @override
  State<DurationCell> createState() => _DurationCellState();
}

class _DurationCellState extends State<DurationCell> {
  late TextEditingController _c;
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.value ?? '');
    _focus.addListener(() {
      setState(() => _focused = _focus.hasFocus);
      if (!_focus.hasFocus) {
        widget.onChanged(_c.text.isEmpty ? null : _c.text);
      }
    });
  }

  @override
  void didUpdateWidget(covariant DurationCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) _c.text = widget.value ?? '';
  }

  @override
  void dispose() {
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: _c,
        focusNode: _focus,
        style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.inputFill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          hintText: '',
          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.inputBorder, width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.accent, width: 2)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.inputBorder, width: 1)),
        ),
        onSubmitted: (v) => widget.onChanged(v.isEmpty ? null : v),
        onTapOutside: (_) {
          if (_focused) widget.onChanged(_c.text.isEmpty ? null : _c.text);
        },
      ),
    );
  }
}

/// Tags on a cell. The picker can also create a tag on the spot, because the
/// whole point of a tag is to label something immediately - making the user
/// leave the cell and go to the column settings first is why tags went unused.
class TagCell extends ConsumerWidget {
  final List<String> selectedIds;
  final ColumnDefinition col;
  final ValueChanged<List<String>> onChanged;
  const TagCell({super.key, required this.selectedIds, required this.col, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = col.tagOptions;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final id in selectedIds)
          Builder(builder: (_) {
            TagOption? o;
            for (final c in options) {
              if (c.id == id) {
                o = c;
                break;
              }
            }
            // A tag can be plain text (no colour) or a colour tag. An
            // uncoloured one is a chip with a border, not a tint.
            final bg = o != null && o.hasColor ? _hex(o.colorHex).withValues(alpha: 0.18) : AppColors.inputFill;
            final border = o != null && o.hasColor ? _hex(o.colorHex) : AppColors.border;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: border, width: 1)),
              child: Text(o?.label ?? id, style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
            );
          }),
        InkWell(
          onTap: () => _pick(context, ref),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inputBorder)),
            child: Icon(Icons.add, size: 14, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final res = await showDialog<({List<String> selected, List<TagOption> options})>(
      context: context,
      builder: (_) => TagPickerDialog(options: col.tagOptions, selected: selectedIds),
    );
    if (res == null) return;
    if (!listEquals(res.options, col.tagOptions)) {
      // A tag was created or removed: save it on the column, not just in the
      // cell, or it would vanish the next time the column reloads.
      final svc = ref.read(supabaseServiceProvider);
      await svc.updateColumn(ColumnDefinition(
        id: col.id,
        label: col.label,
        type: col.type,
        position: col.position,
        config: {...col.config, 'options': res.options.map((e) => e.toJson()).toList()},
        visibleDays: col.visibleDays,
      ));
    }
    onChanged(res.selected);
  }
}

class TagPickerDialog extends StatefulWidget {
  final List<TagOption> options;
  final List<String> selected;
  const TagPickerDialog({super.key, required this.options, required this.selected});
  @override
  State<TagPickerDialog> createState() => _TagPickerState();
}

class _TagPickerState extends State<TagPickerDialog> {
  late Set<String> sel;
  late List<TagOption> options;
  final _newLabel = TextEditingController();
  Color? _newColor;

  @override
  void initState() {
    super.initState();
    sel = widget.selected.toSet();
    options = List.of(widget.options);
  }

  @override
  void dispose() {
    _newLabel.dispose();
    super.dispose();
  }

  /// Adds the typed tag, coloured if a colour was chosen and plain text if not,
  /// and selects it straight away.
  void _create() {
    final label = _newLabel.text.trim();
    if (label.isEmpty) return;
    // A tag that already exists is not duplicated: it is just selected.
    final existing = options.where((o) => o.label.toLowerCase() == label.toLowerCase()).toList();
    final TagOption tag;
    if (existing.isNotEmpty) {
      tag = existing.first;
    } else {
      tag = TagOption(
        id: 'tag_${DateTime.now().microsecondsSinceEpoch}',
        label: label,
        colorHex: _newColor == null ? '' : '#${_newColor!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
      );
      options = [...options, tag];
    }
    setState(() {
      sel.add(tag.id);
      _newLabel.clear();
      _newColor = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
      title: Text(t.tagsTitle, style: TextStyle(color: AppColors.textPrimary)),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (options.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(t.noTagsYet, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: options
                    .map((o) => FilterChip(
                          label: Text(o.label, style: const TextStyle(fontSize: 12)),
                          selected: sel.contains(o.id),
                          // A plain text tag has no tint; a colour tag does.
                          backgroundColor: o.hasColor ? _hex(o.colorHex).withValues(alpha: 0.25) : AppColors.inputFill,
                          selectedColor: o.hasColor ? _hex(o.colorHex).withValues(alpha: 0.25) : AppColors.inputFill,
                          side: BorderSide(color: sel.contains(o.id) && o.hasColor ? _hex(o.colorHex) : AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onSelected: (v) => setState(() => v ? sel.add(o.id) : sel.remove(o.id)),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Text(t.newTagLbl, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(children: [
            // Colour is optional: a tag with no colour is a text tag.
            GestureDetector(
              onTap: () async {
                final c = await showDialog<Color>(context: context, builder: (_) => ColorPickerDialog(initial: _newColor));
                if (c != null) setState(() => _newColor = c);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _newColor ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _newColor == null ? AppColors.textSecondary : AppColors.border, width: _newColor == null ? 1.5 : 1),
                ),
                child: _newColor == null ? Icon(Icons.palette_outlined, size: 16, color: AppColors.textSecondary) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _newLabel,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: t.newTagHint,
                  hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _create(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _create, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)), child: Text(t.addBtn, style: const TextStyle(fontSize: 12))),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, (selected: sel.toList(), options: options)), child: Text(t.okBtn)),
      ],
    );
  }
}

class ScheduleCell extends StatelessWidget {
  final String? value; // stored as "HH:mm" e.g. "09:00" or "9:00 AM"
  final ValueChanged<String?> onChanged;
  const ScheduleCell({super.key, required this.value, required this.onChanged});

  TimeOfDay? _parse(String? v) {
    if (v == null || v.isEmpty) return null;
    // try HH:mm
    try {
      final parts = v.split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1].substring(0, 2));
        return TimeOfDay(hour: h, minute: m);
      }
    } catch (_) {}
    // try with AM/PM via TimeOfDay
    try {
      // fallback: try parsing "9:00 AM"
      final cleaned = v.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      final isPM = cleaned.contains('PM');
      final isAM = cleaned.contains('AM');
      final timePart = cleaned.replaceAll(RegExp(r'[AP]M'), '').trim();
      final parts = timePart.split(':');
      if (parts.length >= 2) {
        int h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        if (isPM && h < 12) h += 12;
        if (isAM && h == 12) h = 0;
        return TimeOfDay(hour: h, minute: m);
      } else if (parts.length == 1) {
        int h = int.parse(parts[0]);
        if (isPM && h < 12) h += 12;
        if (isAM && h == 12) h = 0;
        return TimeOfDay(hour: h, minute: 0);
      }
    } catch (_) {}
    return null;
  }

  String _format(TimeOfDay t, BuildContext context) {
    // Use MaterialLocalizations to format to e.g., 9:00 AM
    return t.format(context);
  }

  @override
  Widget build(BuildContext context) {
    final tod = _parse(value);
    final hasValue = tod != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final initial = tod ?? TimeOfDay.now();
        final picked = await showTimePicker(context: context, initialTime: initial);
        if (picked != null) {
          final stored = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
          onChanged(stored);
        }
      },
      onLongPress: hasValue ? () => onChanged(null) : null,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasValue ? AppColors.accent.withValues(alpha: 0.6) : AppColors.inputBorder, width: 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.access_time_rounded, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              tod != null ? _format(tod, context) : '—',
              style: TextStyle(fontSize: 11, color: hasValue ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ]),
      ),
    );
  }
}
