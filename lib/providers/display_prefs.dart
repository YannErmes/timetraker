import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_providers.dart';

/// Device-level custom background (shared by all users on this device).
final customBgBytesProvider = StateProvider<Uint8List?>((ref) => null);

/// Device-level background brightness 0.15 (dim) .. 1.0 (full).
final customBgBrightnessProvider = StateProvider<double>((ref) => 0.55);

class DisplayPrefs {
  final int rowsVisible; // 0 = all
  final int daysVisible; // 0 = all (7)
  final bool basicCells; // true = compact icon-only timer/status cells
  final String theme; // dark | light | custom
  // First-install defaults: light theme + Basic layout.
  const DisplayPrefs({this.rowsVisible = 0, this.daysVisible = 0, this.basicCells = true, this.theme = 'light'});
  bool get lightMode => theme == 'light';
  DisplayPrefs copyWith({int? rowsVisible, int? daysVisible, bool? basicCells, String? theme}) =>
      DisplayPrefs(rowsVisible: rowsVisible ?? this.rowsVisible, daysVisible: daysVisible ?? this.daysVisible, basicCells: basicCells ?? this.basicCells, theme: theme ?? this.theme);
  Map<String, dynamic> toJson() => {'rowsVisible': rowsVisible, 'daysVisible': daysVisible, 'basicCells': basicCells, 'theme': theme};
  factory DisplayPrefs.fromJson(Map<String, dynamic> j) {
    // Back-compat with the old lightMode bool.
    String theme = 'light';
    if (j['theme'] is String) {
      theme = j['theme'] as String;
    } else if (j['lightMode'] is bool) {
      theme = (j['lightMode'] as bool) ? 'light' : 'dark';
    }
    if (theme != 'dark' && theme != 'light' && theme != 'custom') theme = 'light';
    return DisplayPrefs(
      rowsVisible: (j['rowsVisible'] as num?)?.toInt() ?? 0,
      daysVisible: (j['daysVisible'] as num?)?.toInt() ?? 0,
      basicCells: (j['basicCells'] as bool?) ?? true,
      theme: theme,
    );
  }
}

class DisplayPrefsNotifier extends StateNotifier<DisplayPrefs> {
  final Ref ref;
  DisplayPrefsNotifier(this.ref) : super(const DisplayPrefs()) {
    _load();
    // Identity resolves async AFTER providers are built; reload then so we
    // read/write the real user's key instead of the 'anon' fallback.
    ref.listen(identityStreamProvider, (_, __) => _load());
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

  Future<void> setBasicCells(bool v) async {
    state = state.copyWith(basicCells: v);
    await _save();
  }

  Future<void> setLightMode(bool v) async {
    state = state.copyWith(theme: v ? 'light' : 'dark');
    await _save();
  }

  Future<void> setTheme(String v) async {
    if (v != 'dark' && v != 'light' && v != 'custom') return;
    state = state.copyWith(theme: v);
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
