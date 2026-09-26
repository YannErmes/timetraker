import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_providers.dart';
import '../models/column_definition.dart';

class ColumnVisibilityNotifier extends StateNotifier<Set<String>> {
  final Ref ref;
  ColumnVisibilityNotifier(this.ref) : super({}) {
    _load();
    // keep visibility in sync when columns change (new columns default visible)
    ref.listen(supabaseServiceProvider, (_, __) => _syncWithColumns());
    // Identity resolves async AFTER providers are built; reload then so we
    // read the real user's key instead of the 'anon' fallback.
    ref.listen(identityStreamProvider, (_, __) => _load());
  }

  String _key(String userId) => 'column_visibility_hidden_$userId';

  Future<void> _load() async {
    final svc = ref.read(supabaseServiceProvider);
    final uid = svc.userId ?? 'anon';
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<String>();
        state = Set<String>.from(list);
      } catch (_) {
        state = {};
      }
    } else {
      state = {};
    }
    _syncWithColumns();
  }

  void _syncWithColumns() {
    // hidden set should only contain ids that actually exist; if a column was deleted, remove it
    final cols = ref.read(supabaseServiceProvider).columns;
    final ids = cols.map((c) => c.id).toSet();
    final filtered = state.where((id) => ids.contains(id)).toSet();
    if (filtered.length != state.length) {
      state = filtered;
      _save();
    }
  }

  Future<void> _save() async {
    final svc = ref.read(supabaseServiceProvider);
    final uid = svc.userId ?? 'anon';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), jsonEncode(state.toList()));
  }

  bool isVisible(ColumnDefinition col) => !state.contains(col.id);

  void toggle(String columnId) {
    final next = Set<String>.from(state);
    if (next.contains(columnId)) {
      next.remove(columnId);
    } else {
      next.add(columnId);
    }
    state = next;
    _save();
  }

  void setVisible(String columnId, bool visible) {
    final next = Set<String>.from(state);
    if (visible) {
      next.remove(columnId);
    } else {
      next.add(columnId);
    }
    state = next;
    _save();
  }

  void showAll(List<ColumnDefinition> cols) {
    state = {};
    _save();
  }

  void hideAll(List<ColumnDefinition> cols) {
    state = cols.map((c) => c.id).toSet();
    _save();
  }

  void showOnly(String columnId, List<ColumnDefinition> cols) {
    // hide all except columnId
    state = cols.where((c) => c.id != columnId).map((c) => c.id).toSet();
    _save();
  }
}

final columnVisibilityProvider = StateNotifierProvider<ColumnVisibilityNotifier, Set<String>>((ref) => ColumnVisibilityNotifier(ref));
