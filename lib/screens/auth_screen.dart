import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../config/supabase_config.dart';
import '../providers/app_providers.dart';

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
    final email = _emailCtrl.text.trim();
    final vip = _vipCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final identity = ref.read(identityServiceProvider);
      await identity.signInWithEmail(email, vipKey: vip.isEmpty ? null : vip);
      // SupabaseService will auto-recreate and init via provider watch — no manual reload needed
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', '').replaceAll('ArgumentError: ', ''));
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            color: AppColors.surface,
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.person_rounded, size: 32, color: AppColors.accent),
                const SizedBox(height: 12),
                const Text('Welcome to Tracker Sheet', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Enter your email to continue. We’ll create your workspace instantly — no password needed.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Email address *', hintText: 'e.g. alex@example.com', prefixIcon: Icon(Icons.email_outlined, size: 18)),
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _vipCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'VIP key (optional)',
                    prefixIcon: Icon(Icons.workspace_premium_outlined, size: 18),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                if (!isSupabaseConfigured) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5))),
                    child: const Row(children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFF59E0B)),
                      SizedBox(width: 8),
                      Expanded(child: Text('Cloud is NOT configured in this build — data will stay on THIS device only and will not appear on your other devices.', style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                  const SizedBox(height: 8),
                ],
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                  child: Row(children: const [
                    Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Expanded(child: Text('your email is your only key to your data — remember exactly how you typed it', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic))),
                  ]),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.cancelBorder, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Continue'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Works on web and Android. Your data syncs instantly via Supabase — if you’re offline, edits queue and retry.', style: TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
