import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../config/ui_style.dart';
import '../providers/app_providers.dart';

/// Suggestion inbox dialog: motivational message + name/message form.
/// Sent rows land in the Supabase `suggestions` table.
class SuggestionDialog extends ConsumerStatefulWidget {
  const SuggestionDialog({super.key});
  @override
  ConsumerState<SuggestionDialog> createState() => _SuggestionDialogState();
}

class _SuggestionDialogState extends ConsumerState<SuggestionDialog> {
  late final TextEditingController _nameCtrl;
  final _msgCtrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: ref.read(identityServiceProvider).name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(supabaseServiceProvider).submitSuggestion(name: _nameCtrl.text, message: _msgCtrl.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      final loc = mounted ? AppLocalizations.of(context) : null;
      final msg = e.toString();
      setState(() {
        if (mounted && msg.contains('write your suggestion') && loc != null) {
          _error = loc.errWriteFirst;
        } else if (mounted && msg.contains('not configured') && loc != null) {
          _error = loc.errNoCloud;
        } else {
          _error = msg.replaceAll('Exception: ', '').replaceAll('StateError: ', '').replaceAll('ArgumentError: ', '');
        }
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.border)),
      title: Row(children: [
        Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(t.shapeTitle, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
      ]),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: _sent ? _thanks(t) : _form(t),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(_sent ? t.close : t.cancel)),
        if (!_sent)
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 14),
            label: Text(t.sendBtn),
          ),
      ],
    );
  }

  Widget _form(AppLocalizations t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        ),
        child: Text(
          t.shapeMsg,
          style: TextStyle(fontSize: 11, color: AppColors.textPrimary, height: 1.5),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _nameCtrl,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(labelText: t.nameEmailLbl, prefixIcon: Icon(Icons.person_outline, size: 16)),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _msgCtrl,
        maxLines: 4,
        minLines: 3,
        autofocus: true,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(labelText: t.suggLbl, hintText: t.suggHint, alignLabelWithHint: true),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 12)),
      ],
    ]);
  }

  Widget _thanks(AppLocalizations t) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.15), shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 28, color: Color(0xFF22C55E)),
      ),
      const SizedBox(height: 12),
      Text(t.thankTitle, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
      const SizedBox(height: 6),
      Text(t.thanksText,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
    ]);
  }
}

/// AppBar action that opens the suggestion dialog.
class SuggestionButton extends ConsumerWidget {
  const SuggestionButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    return IconButton(
      icon: Icon(Icons.lightbulb_outline_rounded, color: AppColors.textSecondary),
      tooltip: t.suggestIdea,
      onPressed: () => showDialog(context: context, builder: (_) => const SuggestionDialog()),
    );
  }
}
