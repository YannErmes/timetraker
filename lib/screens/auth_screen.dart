import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../config/supabase_config.dart';
import '../providers/app_providers.dart';
import '../widgets/suggestion_dialog.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _vipCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    final email = _emailCtrl.text.trim();
    final vip = _vipCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = loc.errEmail);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final identity = ref.read(identityServiceProvider);
      await identity.signInWithEmail(email, vipKey: vip.isEmpty ? null : vip);
      // SupabaseService will auto-recreate and init via provider watch — no manual reload needed
    } catch (e) {
      final msg = e.toString();
      final loc2 = mounted ? AppLocalizations.of(context) : null;
      setState(() => _error = msg.contains('VIP key') && loc2 != null
          ? loc2.errVip
          : msg.replaceAll('Exception: ', '').replaceAll('ArgumentError: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _vipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            color: AppColors.surface,
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_rounded, size: 32, color: AppColors.accent),
                const SizedBox(height: 12),
                Text(t.welcome, style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(t.emailContinue, style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.eco_outlined, size: 14, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Expanded(child: Text(t.whyWorks, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                    ]),
                    const SizedBox(height: 4),
                    Text(t.whyText,
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.45)),
                    const SizedBox(height: 6),
                    Text(t.studyQuote,
                        style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontStyle: FontStyle.italic, height: 1.45)),
                    const SizedBox(height: 4),
                    Text(t.studyRef,
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  ]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(labelText: t.emailLbl, hintText: t.emailHint, prefixIcon: Icon(Icons.email_outlined, size: 18)),
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _vipCtrl,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: t.vipLbl,
                    prefixIcon: Icon(Icons.workspace_premium_outlined, size: 18),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                if (!isSupabaseConfigured) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5))),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFF59E0B)),
                      SizedBox(width: 8),
                      Expanded(child: Text(t.cloudNotConfigured, style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                  const SizedBox(height: 8),
                ],
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Expanded(child: Text(t.emailKeyNote, style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic))),
                  ]),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: AppColors.cancelBorder, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(t.continueBtn),
                  ),
                ),
                const SizedBox(height: 8),
                Text(t.worksLine, style: TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
                TextButton.icon(
                  onPressed: () => showDialog(context: context, builder: (_) => const SuggestionDialog()),
                  icon: Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppColors.accent),
                  label: Text(t.suggestLink, style: TextStyle(fontSize: 11, color: AppColors.accent)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
