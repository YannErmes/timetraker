import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../models/column_definition.dart';
import '../models/enums.dart';
import '../providers/app_providers.dart';
import '../services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Storage: notes are saved as Quill delta JSON. Older plain-text notes load
// as-is (inserted as a plain paragraph), so nothing ever breaks.
// ---------------------------------------------------------------------------

/// Parse stored note value into a Quill document (delta JSON or legacy text).
Document docFromStored(dynamic raw) {
  if (raw is String && raw.trimLeft().startsWith('[')) {
    try {
      return Document.fromJson(jsonDecode(raw) as List);
    } catch (_) {}
  }
  final doc = Document();
  if (raw is String && raw.isNotEmpty) {
    doc.insert(0, raw);
  }
  return doc;
}

/// Serialize a document for storage. Empty notes collapse to ''.
String storedFromDoc(Document doc) {
  try {
    if (doc.toPlainText().trim().isEmpty) return '';
  } catch (_) {
    return '';
  }
  return jsonEncode(doc.toDelta().toJson());
}

/// Plain-text excerpt of a stored note (delta JSON or legacy text).
String notePlainText(dynamic raw) {
  if (raw is! String || raw.isEmpty) return '';
  try {
    return docFromStored(raw).toPlainText().trim();
  } catch (_) {
    return raw;
  }
}

/// A column counts as a "note" when it is the note column or a text column
/// whose label mentions notes. These open the sidebar editor instead of
/// inline editing.
bool isNoteColumn(ColumnDefinition c) =>
    c.id == 'col_note' || (c.type == ColumnType.text && c.label.toLowerCase().contains('note'));

/// Compact "tap to open notes" cell used wherever a note lives.
class OpenNotesCell extends ConsumerWidget {
  final String taskId;
  final DateTime date;
  final ColumnDefinition col;
  final dynamic rawValue;
  const OpenNotesCell({super.key, required this.taskId, required this.date, required this.col, required this.rawValue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final plain = notePlainText(rawValue);
    final firstLine = plain.isEmpty ? t.writeNoteEmpty : plain.split('\n').first;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => ref.read(noteEditorRequestProvider.notifier).state =
          NoteEditorRequest(taskId: taskId, date: date, columnId: col.id),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: plain.isEmpty ? AppColors.inputBorder : AppColors.accent.withValues(alpha: 0.6)),
        ),
        child: Row(children: [
          Icon(Icons.notes_rounded, size: 13, color: plain.isEmpty ? AppColors.textSecondary : AppColors.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(firstLine,
                style: TextStyle(fontSize: 11, color: plain.isEmpty ? AppColors.textSecondary : AppColors.textPrimary, fontStyle: plain.isEmpty ? FontStyle.italic : FontStyle.normal),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
          Icon(Icons.open_in_new_rounded, size: 12, color: AppColors.textSecondary),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Note studio sidebar: WYSIWYG editing, live preview, autosave.
// ---------------------------------------------------------------------------

/// Full note studio in the end-drawer sidebar: formatting toolbar
/// (bold, italic, underline, strike, colors, highlighter, headings,
/// bullets, checklists), Edit/Preview tabs, autosave while typing,
/// Save (save + close).
class NoteEditorPanel extends ConsumerStatefulWidget {
  const NoteEditorPanel({super.key});
  @override
  ConsumerState<NoteEditorPanel> createState() => _NoteEditorPanelState();
}

class _NoteEditorPanelState extends ConsumerState<NoteEditorPanel> {
  late final SupabaseService _svc;
  late final String _taskId;
  late final DateTime _date;
  late final String _colId;
  late final String _taskName;
  late final String _colLabel;
  late final QuillController _quill;
  late final FocusNode _focus;
  late final ScrollController _editScroll;
  QuillController? _previewCtrl;
  Timer? _debounce;
  bool _saving = false;
  DateTime? _savedAt;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _svc = ref.read(supabaseServiceProvider);
    final req = ref.read(noteEditorRequestProvider)!;
    _taskId = req.taskId;
    _date = req.date;
    _colId = req.columnId;
    _taskName = _svc.tasks.where((t) => t.id == _taskId).firstOrNull?.name ?? 'Note';
    _colLabel = _svc.columns.where((c) => c.id == _colId).firstOrNull?.label ?? 'note';
    final entry = _svc.entryFor(_taskId, _date);
    _quill = QuillController(
      document: docFromStored(entry?.data[_colId]),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quill.addListener(_onDocChanged);
    _focus = FocusNode();
    _editScroll = ScrollController();
  }

  @override
  void dispose() {
    _flushSave();
    _quill.removeListener(_onDocChanged);
    _quill.dispose();
    _previewCtrl?.dispose();
    _focus.dispose();
    _editScroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onDocChanged() {
    if (!mounted) return;
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () => _saveNow(silent: true));
  }

  Future<void> _saveNow({bool silent = false}) async {
    String? value;
    try {
      final text = _quill.document.toPlainText().trim();
      value = text.isEmpty ? null : storedFromDoc(_quill.document);
    } catch (_) {
      return;
    }
    if (!silent && mounted) setState(() => _saving = true);
    try {
      await _svc.setCellValue(_taskId, _date, _colId, value);
      if (mounted) {
        setState(() {
          _saving = false;
          _savedAt = DateTime.now();
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _saving = false);
    }
  }

  void _flushSave() {
    _debounce?.cancel();
    String? value;
    try {
      final text = _quill.document.toPlainText().trim();
      value = text.isEmpty ? null : storedFromDoc(_quill.document);
    } catch (_) {
      return;
    }
    unawaited(_svc.setCellValue(_taskId, _date, _colId, value));
  }

  void _close() {
    _flushSave();
    ref.read(noteEditorRequestProvider.notifier).state = null;
    if (mounted) Navigator.of(context).pop();
  }

  void _setPreview(bool v) {
    if (v == _preview) return;
    if (v) {
      // Snapshot the live document into a read-only preview controller.
      try {
        final data = jsonDecode(jsonEncode(_quill.document.toDelta().toJson())) as List;
        _previewCtrl?.dispose();
        _previewCtrl = QuillController(
          document: Document.fromJson(data),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
      } catch (_) {
        _previewCtrl?.dispose();
        _previewCtrl = null;
      }
    } else {
      _previewCtrl?.dispose();
      _previewCtrl = null;
    }
    setState(() => _preview = v);
  }

  String _statusText(AppLocalizations t) {
    if (_saving) return t.savingNow;
    if (_savedAt != null) {
      final time = _savedAt!;
      final stamp = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
      return t.autosavedAt(stamp);
    }
    return t.autosavesHint;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Drawer(
      backgroundColor: AppColors.surface,
      width: 400,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.border)),
      child: SafeArea(
        child: Column(children: [
          Container(
            color: AppColors.header,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(Icons.notes_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_taskName.isEmpty ? t.untitledCap : _taskName,
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
                      child: Text('${_date.month}/${_date.day}/${_date.year}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)),
                    ),
                    const SizedBox(width: 6),
                    Flexible(child: Text(_colLabel, style: TextStyle(fontSize: 10, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                  ]),
                ]),
              ),
              IconButton(icon: Icon(Icons.close, size: 18, color: AppColors.textSecondary), tooltip: t.close, onPressed: _close),
            ]),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(t.tabEdit), icon: Icon(Icons.edit_outlined, size: 14)),
                ButtonSegment(value: true, label: Text(t.tabPreview), icon: Icon(Icons.visibility_outlined, size: 14)),
              ],
              selected: {_preview},
              onSelectionChanged: (s) => _setPreview(s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          if (!_preview)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: QuillSimpleToolbar(
                controller: _quill,
                config: const QuillSimpleToolbarConfig(
                  showDividers: true,
                  showFontFamily: false,
                  showFontSize: false,
                  showBoldButton: true,
                  showItalicButton: true,
                  showSmallButton: false,
                  showUnderLineButton: true,
                  showLineHeightButton: false,
                  showStrikeThrough: true,
                  showInlineCode: false,
                  showColorButton: true,
                  showBackgroundColorButton: true,
                  showClearFormat: true,
                  showAlignmentButtons: false,
                  showLeftAlignment: false,
                  showCenterAlignment: false,
                  showRightAlignment: false,
                  showJustifyAlignment: false,
                  showHeaderStyle: true,
                  showListNumbers: true,
                  showListBullets: true,
                  showListCheck: true,
                  showCodeBlock: false,
                  showQuote: false,
                  showIndent: false,
                  showLink: false,
                  showUndo: true,
                  showRedo: true,
                  showDirection: false,
                  showSearchButton: false,
                  showSubscript: false,
                  showSuperscript: false,
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _preview
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: _previewCtrl == null
                          ? Text(t.previewEmpty, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic))
                          : QuillEditor.basic(controller: _previewCtrl!),
                    )
                  : Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: QuillEditor.basic(
                        controller: _quill,
                        focusNode: _focus,
                        scrollController: _editScroll,
                        config: QuillEditorConfig(placeholder: t.writeHint),
                      ),
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Icon(Icons.cloud_done_outlined, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text(_statusText(t), style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
              TextButton(onPressed: _close, child: Text(t.close)),
              const SizedBox(width: 4),
              FilledButton.icon(onPressed: () => _saveNow().then((_) => _close()), icon: const Icon(Icons.check_rounded, size: 14), label: Text(t.save)),
            ]),
          ),
        ]),
      ),
    );
  }
}
