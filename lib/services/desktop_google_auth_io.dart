import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/google_config.dart';
import 'desktop_google_tokens.dart';

/// Google sign-in for the Windows build, done by hand.
///
/// The `google_sign_in` plugin only implements Android, iOS, macOS and web, so
/// on Windows the call fails outright and Calendar sync never connects. Google
/// supports installed apps through the "loopback" flow instead: the app opens
/// the customer's browser, Google redirects back to http://localhost:8787 with
/// an authorization code, and the app exchanges that code for tokens.
///
/// Needs a *Desktop app* OAuth client in the same Google Cloud project, with
/// the redirect URI below registered. See google_config.dart.
class DesktopGoogleAuth {
  /// Must match a redirect URI registered on the desktop OAuth client.
  static const int port = 8787;
  static const String redirectUri = 'http://localhost:$port/oauth2callback';
  static const String _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const String _userInfoEndpoint = 'https://www.googleapis.com/oauth2/v2/userinfo';
  static const String _emailScope = 'https://www.googleapis.com/auth/userinfo.email';

  /// True when the build can do the loopback flow and has a desktop client
  /// configured for it.
  static bool get isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows && hasGoogleDesktopClient;

  /// Opens the browser, waits for the redirect, and stores the tokens.
  /// Returns the signed-in email, or null if the customer cancelled.
  static Future<DesktopGoogleTokens?> signIn({required String scope}) async {
    if (!hasGoogleDesktopClient) {
      throw const DesktopGoogleNotConfigured();
    }

    final server = await _bindOrExplain();

    try {
      final code = await _awaitCode(server, scope);
      if (code == null) return null; // cancelled or denied
      final tokens = await _exchangeCode(code);
      final email = await _fetchEmail(tokens.accessToken);
      final stored = DesktopGoogleTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresAt: DateTime.now().add(Duration(seconds: tokens.expiresIn)),
        email: email,
      );
      await DesktopGoogleTokenStore.save(stored);
      return stored;
    } finally {
      await server.close(force: true);
    }
  }

  /// A usable token, refreshing it first when it has expired.
  static Future<DesktopGoogleTokens?> credentials() async {
    final t = await DesktopGoogleTokenStore.load();
    if (t == null) return null;
    if (!t.isExpired) return t;
    try {
      final res = await http.post(Uri.parse(_tokenEndpoint), body: {
        'grant_type': 'refresh_token',
        'client_id': googleDesktopClientId,
        'client_secret': googleDesktopClientSecret,
        'refresh_token': t.refreshToken,
      });
      if (res.statusCode != 200) {
        debugPrint('desktop google refresh failed: ${res.statusCode} ${res.body}');
        return null;
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final refreshed = DesktopGoogleTokens(
        accessToken: '${j['access_token']}',
        // Google only sends a refresh token the first time.
        refreshToken: t.refreshToken,
        expiresAt: DateTime.now().add(Duration(seconds: (j['expires_in'] as num?)?.toInt() ?? 3600)),
        email: t.email,
      );
      await DesktopGoogleTokenStore.save(refreshed);
      return refreshed;
    } catch (e) {
      debugPrint('desktop google refresh error: $e');
      return null;
    }
  }

  static Future<void> signOut() => DesktopGoogleTokenStore.clear();

  static Future<String?> connectedEmail() async => (await DesktopGoogleTokenStore.load())?.email;

  /// A Calendar client built straight from the stored tokens. The auto
  /// refreshing client gets a new access token on its own once this one
  /// expires, so sync keeps working for as long as the refresh token lives.
  static Future<CalendarApi?> calendarApi() async {
    final t = await credentials();
    if (t == null) return null;
    final client = autoRefreshingClient(
      ClientId(googleDesktopClientId, googleDesktopClientSecret),
      AccessCredentials(
        AccessToken('Bearer', t.accessToken, t.expiresAt),
        t.refreshToken,
        const [],
      ),
      http.Client(),
    );
    return CalendarApi(client);
  }

  // --- the flow ------------------------------------------------------------

  /// The local web server Google redirects back to. Only one app instance can
  /// hold the port, so a second window gets a clear message instead of a
  /// silent failure.
  static Future<HttpServer> _bindOrExplain() async {
    try {
      return await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException {
      throw const DesktopGooglePortBusy();
    }
  }

  /// Opens the consent screen and waits for the code to come back.
  static Future<String?> _awaitCode(HttpServer server, String scope) async {
    final state = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final url = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': googleDesktopClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': '$scope $_emailScope',
      // offline + consent is what makes Google hand over a refresh token.
      'access_type': 'offline',
      'prompt': 'consent',
      'include_granted_scopes': 'true',
      'state': state,
    });

    final code = Completer<String?>();
    HttpResponse? replyTo;

    server.listen((req) async {
      final q = req.uri.queryParameters;
      // Google may probe the favicon before the real redirect arrives.
      if (!q.containsKey('code') && !q.containsKey('error')) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      if (q['state'] != state) {
        req.response.statusCode = HttpStatus.badRequest;
        await req.response.close();
        if (!code.isCompleted) code.complete(null);
        return;
      }
      replyTo = req.response;
      if (!code.isCompleted) {
        final err = q['error'];
        if (err != null) {
          debugPrint('desktop google denied: $err ${q['error_description'] ?? ''}');
          code.complete(null);
        } else {
          code.complete(q['code']);
        }
      }
    });

    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched) {
      await server.close(force: true);
      throw const DesktopGoogleNoBrowser();
    }

    // Give up eventually: a customer who walks away must not leave the app
    // waiting (and the port held) forever.
    final done = await code.future
        .timeout(const Duration(minutes: 5), onTimeout: () => null)
        .then<String?>((v) => v);
    if (!code.isCompleted) code.complete(null);

    if (replyTo != null) {
      try {
        replyTo!.headers.contentType = ContentType.html;
        replyTo!.write(_resultPage(done != null));
        await replyTo!.close();
      } catch (_) {}
    }
    return done;
  }

  /// Browser page shown once Google redirects back, so the tab does not just
  /// sit on an error.
  static String _resultPage(bool ok) => '''<!doctype html>
<html><head><meta charset="utf-8"><title>4cus</title>
<style>body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;background:#0f1115;color:#e8eaf0;
display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
div{text-align:center}h1{font-size:20px;margin:0 0 8px}p{color:#9aa3b5;margin:0;font-size:14px}</style></head>
<body><div><h1>${ok ? 'Google Calendar connected' : 'Not connected'}</h1>
<p>${ok ? 'You can close this tab and go back to 4cus.' : 'Nothing was connected. Go back to 4cus and try again.'}</p>
</div></body></html>''';

  static Future<_RawTokens> _exchangeCode(String code) async {
    final res = await http.post(Uri.parse(_tokenEndpoint), body: {
      'grant_type': 'authorization_code',
      'code': code,
      'client_id': googleDesktopClientId,
      'client_secret': googleDesktopClientSecret,
      'redirect_uri': redirectUri,
    });
    if (res.statusCode != 200) {
      throw DesktopGoogleExchangeFailed('${res.statusCode}: ${_short(res.body)}');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final access = j['access_token'];
    final refresh = j['refresh_token'];
    final expires = (j['expires_in'] as num?)?.toInt() ?? 3600;
    if (access is! String || access.isEmpty) {
      throw const DesktopGoogleExchangeFailed('no access token in the response');
    }
    if (refresh is! String || refresh.isEmpty) {
      // Should not happen with access_type=offline, but without a refresh
      // token sync would die an hour later: fail now, while it is fixable.
      throw const DesktopGoogleExchangeFailed('no refresh token: check that the desktop client id is correct');
    }
    return _RawTokens(access, refresh, expires);
  }

  static Future<String?> _fetchEmail(String accessToken) async {
    try {
      final res = await http.get(Uri.parse(_userInfoEndpoint), headers: {'Authorization': 'Bearer $accessToken'});
      if (res.statusCode != 200) return null;
      return (jsonDecode(res.body) as Map<String, dynamic>)['email'] as String?;
    } catch (_) {
      return null; // the address is only used for display
    }
  }

  static String _short(String body) => body.length > 200 ? '${body.substring(0, 200)}...' : body;
}

class _RawTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  const _RawTokens(this.accessToken, this.refreshToken, this.expiresIn);
}

/// No desktop OAuth client is compiled into this build.
class DesktopGoogleNotConfigured implements Exception {
  const DesktopGoogleNotConfigured();
  @override
  String toString() => 'Google sign-in on Windows needs a Desktop OAuth client (GOOGLE_DESKTOP_CLIENT_ID / GOOGLE_DESKTOP_CLIENT_SECRET).';
}

/// Another copy of the app already owns localhost:$port.
class DesktopGooglePortBusy implements Exception {
  const DesktopGooglePortBusy();
  @override
  String toString() => 'Another 4cus window is already connecting to Google. Close it and try again.';
}

/// The system has no browser to open.
class DesktopGoogleNoBrowser implements Exception {
  const DesktopGoogleNoBrowser();
  @override
  String toString() => 'Could not open a browser to sign in to Google.';
}

/// Google refused the code exchange.
class DesktopGoogleExchangeFailed implements Exception {
  final String detail;
  const DesktopGoogleExchangeFailed(this.detail);
  @override
  String toString() => 'Google sign-in failed ($detail).';
}
