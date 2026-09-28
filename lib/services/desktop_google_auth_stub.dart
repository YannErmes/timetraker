/// Stub for builds that cannot do the OAuth loopback flow (web, Android,
/// iOS). Those platforms use the `google_sign_in` plugin instead, so nothing
/// here is ever called. Selected by the conditional import in
/// desktop_google_auth.dart.
library;

import 'package:googleapis/calendar/v3.dart';

class DesktopGoogleAuth {
  static bool get isAvailable => false;

  static Future<Never> signIn({required String scope}) =>
      throw UnsupportedError('Google loopback sign-in is only available on Windows.');

  static Future<Never> credentials() =>
      throw UnsupportedError('Google loopback sign-in is only available on Windows.');

  static Future<void> signOut() async {}

  static Future<String?> connectedEmail() async => null;

  static Future<CalendarApi?> calendarApi() async => null;
}

class DesktopGoogleNotConfigured implements Exception {
  const DesktopGoogleNotConfigured();
}

class DesktopGooglePortBusy implements Exception {
  const DesktopGooglePortBusy();
}

class DesktopGoogleNoBrowser implements Exception {
  const DesktopGoogleNoBrowser();
}

class DesktopGoogleExchangeFailed implements Exception {
  final String detail;
  const DesktopGoogleExchangeFailed(this.detail);
}
