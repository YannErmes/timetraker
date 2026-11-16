import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';

import '../config/app_colors.dart';
import '../models/task.dart';
import '../providers/app_providers.dart';
import '../services/supabase_service.dart';
import '../utils/task_json.dart';

enum _ImportMode { replace, merge }

/// A side-opening live JSON editor for the task list.
///
/// The table is still the source of truth: every valid edit is diffed into the
/// service, which writes only the rows that actually changed. The panel never
/// covers the grid on desktop — the grid just gets narrower — so the result of
/// an edit is visible while you type.
class JsonTaskPanel extends ConsumerStatefulWidget {
  /// Mobile opens the same widget in a sheet; the close button then has to pop
  /// the sheet as well as flip the provider.
  final bool inSheet;
  const JsonTaskPanel({super.key, this.inSheet = false});

  @override
  ConsumerState<JsonTaskPanel> createState() => _JsonTaskPanelState();
}

class _JsonTaskPanelState extends ConsumerState<JsonTaskPanel> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String? _lastSyncedJson;
  String? _undoJson;
  String? _error;
  int _count = 0;
  int _editVersion = 0;
  bool _dirty = false;
  bool _externalChange = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    // HomeScreen is only built after SupabaseService.init() has finished, so
    // the tasks are already here on first frame.
    _loadFromTable(ref.read(supabaseServiceProvider), notify: false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _loadFromTable(SupabaseService svc, {bool notify = true}) {
    final json = encodeTasksJson(svc.tasks, svc.entries);
    _debounce?.cancel();
    _ctrl.text = json;
    _lastSyncedJson = json;
    _dirty = false;
    _externalChange = false;
    _error = null;
    _count = svc.tasks.length;
    if (notify && mounted) setState(() {});
  }

  /// The table can change while the panel is open (the add button, the cloud
  /// sync, another device). Reflect that — unless the user is mid-edit, in
  /// which case their text wins and we offer a Reload instead of stomping it.
  void _tableChanged() {
    final svc = ref.read(supabaseServiceProvider);
    final json = encodeTasksJson(svc.tasks, svc.entries);
    if (json == _lastSyncedJson) return;
    if (_dirty) {
      if (!_externalChange && mounted) setState(() => _externalChange = true);
      return;
    }
    _ctrl.text = json;
    _lastSyncedJson = json;
    _count = svc.tasks.length;
    _error = null;
    // The sync service sees the same task stream and writes the file for us.
    if (mounted) setState(() {});
  }

  void _onChanged(String _) {
    _editVersion++;
    _dirty = true;
    _externalChange = false;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _applyNow);
    if (mounted) setState(() {});
  }

  Future<void> _applyNow() async {
    if (!mounted) return;
    final svc = ref.read(supabaseServiceProvider);
    final version = _editVersion;
    final List<Task> desired;
    final Map<String, List<DateTime>> desiredDays;
    final bool needsIds;
    try {
      final result = parseTasksJson(
        _ctrl.text,
        userId: svc.userId ?? '',
        byId: svc.taskById,
      );
      desired = result.tasks;
      desiredDays = result.days;
      needsIds = result.needsIds;
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
      return;
    }

    _undoJson ??= _lastSyncedJson;
    if (mounted) setState(() {
      _applying = true;
      _error = null;
    });
    try {
      await svc.applyTaskSnapshot(desired, days: desiredDays);
      if (!mounted) return;
      _lastSyncedJson = encodeTasksJson(svc.tasks, svc.entries);
      _count = desired.length;
      // The sync service mirrors this task change into the linked file.
      // Only settle the "dirty" flag if no new keystroke landed while the
      // writes were in flight; otherwise that edit still needs applying.
      if (version == _editVersion) {
        _dirty = false;
        _externalChange = false;
        _undoJson = null;
        if (needsIds) {
          // Fill in the generated ids once, so the rows keep their identity on
          // the next edit and their day cells do not move to a new task.
          _ctrl.text = _lastSyncedJson ?? _ctrl.text;
        }
      }
    } catch (e) {
      if (mounted) _error = _cleanError(e);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _undo() {
    final previous = _undoJson;
    if (previous == null) return;
    _debounce?.cancel();
    _ctrl.text = previous;
    _editVersion++;
    _dirty = false;
    _undoJson = null;
    _applyNow();
  }

  /// Pick a .json file, then let the customer choose whether it replaces the
  /// whole list or just adds its rows. The parser is the same one used for
  /// typing, so a file that would break the table is rejected before import.
  Future<void> _importFile() async {
    final t = AppLocalizations.of(context)!;
    PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        dialogTitle: t.jsonImport,
      );
    } catch (e) {
      if (mounted) setState(() => _error = t.jsonImportError(_cleanError(e)));
      return;
    }
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    var text = utf8.decode(bytes);
    if (text.startsWith('\uFEFF')) text = text.substring(1); // UTF-8 BOM
    final svc = ref.read(supabaseServiceProvider);
    late final ({List<Task> tasks, Map<String, List<DateTime>> days, bool needsIds}) imported;
    try {
      imported = parseTasksJson(text, userId: svc.userId ?? '', byId: svc.taskById);
    } catch (e) {
      if (mounted) setState(() => _error = t.jsonImportError(_cleanError(e)));
      return;
    }
    if (!mounted) return;

    final mode = await showDialog<_ImportMode>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
        title: Text(t.jsonImportTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.jsonImportBody('${imported.tasks.length}', '${svc.tasks.length}'), style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 14),
          _importOption(
            icon: Icons.swap_horiz_rounded,
            title: t.jsonImportReplace,
            help: t.jsonImportReplaceHelp,
            color: AppColors.cancelText,
            onTap: () => Navigator.pop(context, _ImportMode.replace),
          ),
          const SizedBox(height: 8),
          _importOption(
            icon: Icons.add_rounded,
            title: t.jsonImportMerge,
            help: t.jsonImportMergeHelp,
            color: AppColors.accent,
            onTap: () => Navigator.pop(context, _ImportMode.merge),
          ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel))],
      ),
    );
    if (mode == null || !mounted) return;

    if (mode == _ImportMode.replace) {
      _setEditorText(text);
      await _applyNow();
      if (mounted) _toast(t.jsonImportReplaced('${imported.tasks.length}'));
      return;
    }

    // Merge keeps the editor's current content as the base — it may contain
    // unsaved edits. If that text is broken, fall back to a clean copy of the
    // table rather than refusing the whole import.
    String baseText = _ctrl.text;
    try {
      parseTasksJson(baseText, userId: svc.userId ?? '', byId: svc.taskById);
    } catch (_) {
      baseText = encodeTasksJson(svc.tasks, svc.entries);
    }
    final merged = mergeTaskJson(
      baseText,
      text,
      userId: svc.userId ?? '',
      byId: svc.taskById,
    );
    _setEditorText(merged.json);
    await _applyNow();
    if (mounted) _toast(t.jsonImportMerged('${merged.added}', '${merged.skipped}'));
  }

  void _setEditorText(String text) {
    _debounce?.cancel();
    _ctrl.text = text;
    _editVersion++;
    _dirty = true;
    _externalChange = false;
    _error = null;
  }

  Widget _importOption({
    required IconData icon,
    required String title,
    required String help,
    required Color color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(height: 2),
              Text(help, style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.3)),
            ])),
          ]),
        ),
      );

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 12)),
      backgroundColor: AppColors.header,
      behavior: SnackBarBehavior.floating,
    ));
  }


  static String _cleanError(Object e) {
    var s = e.toString();
    final nl = s.indexOf('\n');
    if (nl > 0) s = s.substring(0, nl);
    return s.length > 150 ? '${s.substring(0, 147)}…' : s;
  }

  void _close() {
    _debounce?.cancel();
    ref.read(jsonPanelOpenProvider.notifier).state = false;
    if (widget.inSheet && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final svc = ref.watch(supabaseServiceProvider);
    // Deliver stream changes on the next frame: a provider can notify during
    // build, and calling setState from inside this build would throw.
    ref.listen(tasksProvider, (_, __) => Future.microtask(_tableChanged));
    ref.listen(entriesProvider, (_, __) => Future.microtask(_tableChanged));

    final status = _error ??
        (_externalChange
            ? t.jsonExternal
            : _dirty
                ? t.jsonTyping
                : t.jsonLive('$_count'));
    final statusColor = _error != null
        ? const Color(0xFFF43F5E)
        : _dirty || _externalChange
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            color: AppColors.header,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              Icon(Icons.data_object, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(t.jsonPanelTitle, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
              IconButton(tooltip: t.jsonImport, icon: const Icon(Icons.file_upload_outlined, size: 16), onPressed: _importFile),
              IconButton(tooltip: t.jsonCopy, icon: const Icon(Icons.copy_outlined, size: 16), onPressed: () {
                Clipboard.setData(ClipboardData(text: _ctrl.text));
              }),
              IconButton(tooltip: t.jsonUndo, icon: const Icon(Icons.undo_rounded, size: 16), onPressed: _undoJson != null ? _undo : null),
              IconButton(tooltip: t.jsonReload, icon: const Icon(Icons.refresh_outlined, size: 16), onPressed: () => _loadFromTable(ref.read(supabaseServiceProvider))),
              IconButton(tooltip: t.jsonClose, icon: const Icon(Icons.close, size: 17), onPressed: _close),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
            child: Text(t.jsonPanelHint, style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary, height: 1.35)),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _error != null ? const Color(0xFFF43F5E) : AppColors.border),
              ),
              child: TextField(
                controller: _ctrl,
                onChanged: _onChanged,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.45),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                  hintText: '[\n  {\n    "name": "Gym"\n  }\n]',
                  hintStyle: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Icon(_error != null ? Icons.error_outline : _applying ? Icons.sync : Icons.check_circle_outline, size: 13, color: statusColor),
              const SizedBox(width: 6),
              Expanded(child: Text(status, style: TextStyle(fontSize: 10.5, color: statusColor), overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ]),
      ),
    );
  }
}
