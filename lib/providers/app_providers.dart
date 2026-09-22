import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final s = SupabaseService();
  ref.onDispose(() => s.dispose());
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

enum ViewMode { weekly, daily, monthly }
