import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';
import '../config/app_colors.dart';
import '../providers/app_providers.dart';
import '../providers/column_visibility.dart';
import '../models/column_definition.dart';
import '../models/enums.dart';

const _uuid = Uuid();

Color _hex(String h) { var s = h.replaceAll('#', ''); if (s.length == 6) s = 'FF$s'; return Color(int.parse(s, radix: 16)); }
String _toHex(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

class ColumnSettingsPanel extends ConsumerWidget {
  const ColumnSettingsPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(supabaseServiceProvider);
    ref.watch(columnsProvider);
    final t = AppLocalizations.of(context)!;
    final cols = List.of(svc.columns)..sort((a, b) => a.position.compareTo(b.position));
    return Drawer(
      backgroundColor: AppColors.surface,
      width: 380,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.border)),
      child: SafeArea(
        child: Column(children: [
          Container(
            color: AppColors.header,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(Icons.view_column, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(t.manageColsTitle, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              const Spacer(),
              FilledButton.icon(onPressed: () => _addColumn(context, ref), icon: const Icon(Icons.add, size: 14), label: Text(t.add)),
            ]),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: EdgeInsets.all(10),
            child: Text(t.introText, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: cols.length,
              onReorder: (o, n) => svc.reorderColumns(o, n),
              itemBuilder: (_, i) {
                final c = cols[i];
                final hidden = ref.watch(columnVisibilityProvider).contains(c.id);
                return Opacity(
                  key: ValueKey(c.id),
                  opacity: hidden ? 0.55 : 1.0,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: hidden ? AppColors.bg : AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: hidden ? AppColors.border.withValues(alpha: 0.6) : AppColors.border)),
                    child: ListTile(
                      leading: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.drag_handle, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Icon(c.type.icon, size: 16, color: hidden ? AppColors.textSecondary : AppColors.accent),
                      ]),
                      title: Row(children: [
                        Expanded(child: Text(c.label, style: TextStyle(color: hidden ? AppColors.textSecondary : AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600, decoration: hidden ? TextDecoration.lineThrough : null))),
                        if (hidden) Container(margin: EdgeInsets.only(left: 6), padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: Text(t.hiddenBadge, style: TextStyle(fontSize: 9, color: AppColors.textSecondary))),
                      ]),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${c.type.labelL(t)} · ${c.type.descL(t)}', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        if (c.type == ColumnType.status)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(spacing: 4, runSpacing: 2, children: c.statusOptions.map((o) => Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _hex(o.colorHex).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8), border: Border.all(color: _hex(o.colorHex).withValues(alpha: 0.5))), child: Text(o.label, style: TextStyle(fontSize: 10, color: AppColors.textPrimary)))).toList()),
                          ),
                      ]),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: hidden ? t.showCol : t.hideCol,
                          icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16, color: hidden ? AppColors.textSecondary : AppColors.accent),
                          onPressed: () => ref.read(columnVisibilityProvider.notifier).toggle(c.id),
                        ),
                        PopupMenuButton(
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
                          onSelected: (v) { if (v == 'edit') _editColumn(context, ref, c); if (v == 'del') _confirmDelete(context, ref, c); if (v == 'toggle') ref.read(columnVisibilityProvider.notifier).toggle(c.id); },
                          itemBuilder: (_) => [PopupMenuItem(value: 'edit', child: Text(t.editTypeItem)), PopupMenuItem(value: 'toggle', child: Text(hidden ? t.showCol : t.hideCol)), PopupMenuItem(value: 'del', child: Text(t.delete))],
                          icon: Icon(Icons.more_horiz, size: 16, color: AppColors.textSecondary),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Text(t.footerDragHelp, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          )
        ]),
      ),
    );
  }

  void _addColumn(BuildContext context, WidgetRef ref) => showDialog(context: context, builder: (_) => _ColumnEditDialog(existing: null));
  void _editColumn(BuildContext context, WidgetRef ref, ColumnDefinition c) => showDialog(context: context, builder: (_) => _ColumnEditDialog(existing: c));
  void _confirmDelete(BuildContext context, WidgetRef ref, ColumnDefinition c) {
    final t = AppLocalizations.of(context)!;
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
      title: Text(t.deleteColTitle, style: TextStyle(color: AppColors.textPrimary)),
      content: Text(t.deleteColBody(c.label), style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      actions: [TextButton(onPressed: ()=> Navigator.pop(context), child: Text(t.cancel)), FilledButton(onPressed: (){ ref.read(supabaseServiceProvider).deleteColumn(c.id); Navigator.pop(context); }, style: FilledButton.styleFrom(backgroundColor: AppColors.cancelFill, foregroundColor: AppColors.cancelText), child: Text(t.delete))],
    ));
  }
}

class _ColumnEditDialog extends ConsumerStatefulWidget {
  final ColumnDefinition? existing;
  const _ColumnEditDialog({required this.existing});
  @override
  ConsumerState<_ColumnEditDialog> createState() => _ColumnEditDialogState();
}

class _ColumnEditDialogState extends ConsumerState<_ColumnEditDialog> {
  late TextEditingController _label;
  late ColumnType _type;
  late List<StatusOption> _statusOpts;
  late String _unit;
  String? _anchorId; // null = end, '__begin' = beginning, else column id
  bool _before = true;
  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.existing?.label ?? '');
    _type = widget.existing?.type ?? ColumnType.text;
    _statusOpts = widget.existing?.statusOptions ??
        [
          const StatusOption(id: 'idle', label: 'idle', colorHex: '#475569'),
          const StatusOption(id: 'none', label: 'none', colorHex: '#64748B'),
          const StatusOption(id: 'done', label: 'done', colorHex: '#22C55E'),
          const StatusOption(id: 'cancel', label: 'cancel', colorHex: '#F43F5E'),
          const StatusOption(id: 'in_progress', label: 'in progress', colorHex: '#F59E0B'),
        ];
    _unit = widget.existing?.unit ?? 'h';
    _anchorId = null; // default append at end
  }

  int _computedPos(List<ColumnDefinition> sorted) {
    if (_anchorId == null) return sorted.length;
    if (_anchorId == '__begin') return 0;
    final idx = sorted.indexWhere((c) => c.id == _anchorId);
    if (idx == -1) return sorted.length;
    return _before ? idx : idx + 1;
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    final originalType = widget.existing?.type;
    final typeChanged = originalType != null && originalType != _type;
    final t = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
      title: Text(isNew ? t.addColTitle : t.editColTitle, style: TextStyle(color: AppColors.textPrimary)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _label, style: TextStyle(color: AppColors.textPrimary), decoration: InputDecoration(labelText: t.colNameLbl)),
          const SizedBox(height: 12),
          DropdownButtonFormField<ColumnType>(
            value: _type,
            dropdownColor: AppColors.surface,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(labelText: t.typeLbl),
            isExpanded: true,
            selectedItemBuilder: (c) => ColumnType.values.map((e) => Row(children: [Icon(e.icon, size: 16, color: AppColors.accent), const SizedBox(width: 8), Text(e.labelL(t))])).toList(),
            items: ColumnType.values.map((e) => DropdownMenuItem(value: e, child: Row(children: [
              Icon(e.icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.labelL(t), style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(e.descL(t), style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
              ])),
            ]))).toList(),
            onChanged: (v) => setState(() => _type = v!),
          ),
          if (typeChanged) ...[
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.inProgressFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.inProgressBorder)), child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.inProgressBorder),
              const SizedBox(width: 8),
              Expanded(child: Text(t.typeChangedWarn(originalType.labelL(t), _type.labelL(t)), style: TextStyle(fontSize: 11, color: AppColors.inProgressText))),
            ])),
          ],
          if (isNew) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.insertPosition, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(t.insertHelp, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final svc = ref.watch(supabaseServiceProvider);
                  final sorted = List.of(svc.columns)..sort((a, b) => a.position.compareTo(b.position));
                  return Column(children: [
                    DropdownButtonFormField<String?>(
                      value: _anchorId,
                      dropdownColor: AppColors.surface,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                      decoration: InputDecoration(labelText: t.anchorLbl, isDense: true),
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(value: '__begin', child: Text(t.atBeginning)),
                        DropdownMenuItem(value: null, child: Text(t.atEnd)),
                        ...sorted.map((c) => DropdownMenuItem(value: c.id, child: Text(c.label.isEmpty ? t.untitledCap : c.label, style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: (v) => setState(() => _anchorId = v),
                    ),
                    if (_anchorId != null && _anchorId != '__begin') ...[
                      const SizedBox(height: 8),
                      SegmentedButton<bool>(
                        segments: [ButtonSegment(value: true, label: Text(t.beforeBtn), icon: Icon(Icons.arrow_upward, size: 14)), ButtonSegment(value: false, label: Text(t.afterBtn), icon: Icon(Icons.arrow_downward, size: 14))],
                        selected: {_before},
                        onSelectionChanged: (s) => setState(() => _before = s.first),
                        style: ButtonStyle(visualDensity: VisualDensity.compact),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Builder(builder: (_) {
                      final pos = _computedPos(sorted);
                      return Text(t.willInsert('${pos + 1}', '${sorted.length + 1}'), style: TextStyle(fontSize: 11, color: AppColors.textSecondary));
                    }),
                  ]);
                }),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          if (_type == ColumnType.number)
            TextField(
              controller: TextEditingController(text: _unit),
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(labelText: t.unitLbl, hintText: t.unitHint),
              onChanged: (v) => _unit = v,
            ),
          if (_type == ColumnType.timer)
            Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: Row(children: [Icon(Icons.hourglass_bottom_rounded, size: 16, color: AppColors.accent), SizedBox(width: 8), Expanded(child: Text(t.timerHelp, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)))])),
          if (_type == ColumnType.status) ...[
            Align(alignment: Alignment.centerLeft, child: Text(t.statusOptsLbl, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
            const SizedBox(height: 6),
            for (int i = 0; i < _statusOpts.length; i++)
              Card(
                color: AppColors.inputFill,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _statusOpts[i].label,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        decoration: InputDecoration(labelText: t.labelFieldLbl, isDense: true),
                        onChanged: (v) {
                          final l = List<StatusOption>.from(_statusOpts);
                          l[i] = StatusOption(id: l[i].id, label: v, colorHex: l[i].colorHex);
                          setState(() => _statusOpts = l);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final c = await showDialog<Color>(context: context, builder: (_) => _ColorPicker(initial: _hex(_statusOpts[i].colorHex)));
                        if (c != null) {
                          final l = List<StatusOption>.from(_statusOpts);
                          l[i] = StatusOption(id: l[i].id, label: l[i].label, colorHex: _toHex(c));
                          setState(() => _statusOpts = l);
                        }
                      },
                      child: Container(width: 32, height: 32, decoration: BoxDecoration(color: _hex(_statusOpts[i].colorHex), shape: BoxShape.circle, border: Border.all(color: AppColors.border))),
                    ),
                    IconButton(icon: Icon(Icons.delete, size: 18, color: AppColors.textSecondary), onPressed: () => setState(() => _statusOpts.removeAt(i))),
                  ]),
                ),
              ),
            TextButton.icon(onPressed: () => setState(() => _statusOpts.add(StatusOption(id: _uuid.v4(), label: 'new', colorHex: '#475569'))), icon: const Icon(Icons.add, size: 16), label: Text(t.addOptionLbl))
          ]
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        FilledButton(onPressed: _save, child: Text(isNew ? t.add : t.save)),
      ],
    );
  }

  Future<void> _save() async {
    final svc = ref.read(supabaseServiceProvider);
    final loc = AppLocalizations.of(context)!;
    final id = widget.existing?.id ?? 'col_${_uuid.v4()}';
    int pos;
    if (widget.existing != null) {
      pos = widget.existing!.position;
    } else {
      final sorted = List.of(svc.columns)..sort((a, b) => a.position.compareTo(b.position));
      pos = _computedPos(sorted);
    }
    Map<String, dynamic> cfg = {};
    if (_type == ColumnType.status) cfg = {'options': _statusOpts.map((e) => e.toJson()).toList()};
    if (_type == ColumnType.number) cfg = {'unit': _unit};
    final col = ColumnDefinition(id: id, label: _label.text.trim().isEmpty ? loc.untitledLower : _label.text.trim(), type: _type, position: pos, config: cfg);
    if (widget.existing != null && widget.existing!.type != _type) {
      final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
        title: Text(loc.changeTypeTitle, style: TextStyle(color: AppColors.textPrimary)),
        content: Text(loc.changeTypeBody(widget.existing!.label, widget.existing!.type.labelL(loc), _type.labelL(loc)), style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        actions: [TextButton(onPressed: ()=> Navigator.pop(context,false), child: Text(loc.cancel)), FilledButton(onPressed: ()=> Navigator.pop(context,true), child: Text(loc.changeBtn))],
      ));
      if (ok != true) return;
    }
    if (widget.existing == null) {
      await svc.addColumn(col);
    } else {
      await svc.updateColumn(col);
    }
    if (mounted) Navigator.pop(context);
  }
}

class _ColorPicker extends StatelessWidget {
  final Color initial;
  const _ColorPicker({required this.initial});
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colors = [const Color(0xFFF43F5E), const Color(0xFF22C55E), const Color(0xFF475569), const Color(0xFFF59E0B), Colors.blue, Colors.purple, Colors.teal, Colors.orange, Colors.pink];
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
      title: Text(loc.pickColorTitle, style: TextStyle(color: AppColors.textPrimary)),
      content: Wrap(spacing: 8, runSpacing: 8, children: colors.map((c) => GestureDetector(onTap: () => Navigator.pop(context, c), child: Container(width: 36, height: 36, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: AppColors.border))))).toList()),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.close))],
    );
  }
}
