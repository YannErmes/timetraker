import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/identity_service.dart';
import '../services/supabase_service.dart';

final identityServiceProvider = Provider<IdentityService>((ref) {
  final s = IdentityService();
  ref.onDispose(() => s.dispose());
  // kick off async init, but caller should await
  s.init();
  return s;
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final identity = ref.watch(identityServiceProvider);
  final s = SupabaseService(identity);
  ref.onDispose(() => s.dispose());
  // init for this identity (fire-and-forget; App also awaits)
  Future.microtask(() => s.init());
  return s;
});

final tasksProvider = StreamProvider((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return svc.tasksStream;
});
final columnsProvider = StreamProvider((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return svc.columnsStream;
});
final entriesProvider = StreamProvider((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return svc.entriesStream;
});

// View state
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final viewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.weekly);
final isFilterSidebarCollapsedProvider = StateProvider<bool>((ref) => false);

enum ViewMode { weekly, daily, monthly }
