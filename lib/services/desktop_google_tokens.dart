import 'package:shared_preferences/shared_preferences.dart';

/// The tokens the desktop (Windows) sign-in stores.
///
/// Windows cannot use the `google_sign_in` plugin — it has no Windows
/// implementation — so the EXE does the OAuth 2.0 loopback flow itself: it
/// opens the customer's browser, Google sends the code back to a small local
/// web server, and that is exchanged for these tokens.
class DesktopGoogleTokens {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String? email;

  const DesktopGoogleTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.email,
  });

  /// Refresh a minute early so a sync never fails mid-request.
  bool get isExpired => DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 1)));

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.toIso8601String(),
        'email': email,
      };

  static DesktopGoogleTokens? fromJson(Map<String, dynamic> j) {
    final access = j['access_token'];
    final refresh = j['refresh_token'];
    final expires = DateTime.tryParse('${j['expires_at'] ?? ''}');
    if (access is! String || access.isEmpty) return null;
    if (refresh is! String || refresh.isEmpty) return null;
    if (expires == null) return null;
    return DesktopGoogleTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expires,
      email: j['email'] as String?,
    );
  }
}

/// Local storage for those tokens. Kept out of the flow implementation so the
/// web build can compile the same model without `dart:io`.
class DesktopGoogleTokenStore {
  static const _key = 'gcal_desktop_tokens';

  static Future<DesktopGoogleTokens?> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null || raw.isEmpty) return null;
      return DesktopGoogleTokens.fromJson(_decodeMap(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(DesktopGoogleTokens t) async {
    try {
      (await SharedPreferences.getInstance()).setString(_key, _encodeMap(t.toJson()));
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }

  // Small hand-rolled map<->string so the model does not need dart:convert in
  // two places; both directions are trivial and the values are ours.
  static Map<String, dynamic> _decodeMap(String raw) {
    final out = <String, dynamic>{};
    for (final part in raw.split('|')) {
      if (part.isEmpty) continue;
      final i = part.indexOf('=');
      if (i <= 0) continue;
      out[part.substring(0, i)] = part.substring(i + 1);
    }
    return out;
  }

  static String _encodeMap(Map<String, dynamic> j) => j.entries
      .map((e) => '${e.key}=${e.value ?? ''}')
      .join('|');
}
