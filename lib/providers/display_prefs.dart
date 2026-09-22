import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_providers.dart';

class DisplayPrefs {
  final int rowsVisible; // 0 = all
  final int daysVisible; // 0 = all (7)
  const DisplayPrefs({this.rowsVisible = 0, this.daysVisible = 0});
  DisplayPrefs copyWith({int? rowsVisible, int? daysVisible}) =>
      DisplayPrefs(rowsVisible: rowsVisible ?? this.rowsVisible, daysVisible: daysVisible ?? this.daysVisible);
  Map<String, dynamic> toJson() => {'rowsVisible': rowsVisible, 'daysVisible': daysVisible};
  factory DisplayPrefs.fromJson(Map<String, dynamic> j) => DisplayPrefs(rowsVisible: (j['rowsVisible'] as num?)?.toInt() ?? 0, daysVisible: (j['daysVisible'] as num?)?.toInt() ?? 0);
}

class DisplayPrefsNotifier extends StateNotifier<DisplayPrefs> {
  final Ref ref;
  DisplayPrefsNotifier(this.ref) : super(const DisplayPrefs()) {
    _load();
  }

  String _key(String userId) => 'display_prefs_$userId';

  Future<void> _load() async {
    final svc = ref.read(supabaseServiceProvider);
    final uid = svc.userId ?? 'anon';
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        state = DisplayPrefs.fromJson(m);
      } catch (_) {}
    }
  }

  Future<void> setRowsVisible(int v) async {
    state = state.copyWith(rowsVisible: v);
    await _save();
  }

  Future<void> setDaysVisible(int v) async {
    state = state.copyWith(daysVisible: v);
    await _save();
  }

  Future<void> _save() async {
    final svc = ref.read(supabaseServiceProvider);
    final uid = svc.userId ?? 'anon';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), jsonEncode(state.toJson()));
  }
}

final displayPrefsProvider = StateNotifierProvider<DisplayPrefsNotifier, DisplayPrefs>((ref) => DisplayPrefsNotifier(ref));
