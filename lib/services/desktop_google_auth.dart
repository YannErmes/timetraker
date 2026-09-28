// Google sign-in for Windows.
//
// `google_sign_in` has no Windows implementation, so on the EXE the plugin
// call fails and Calendar sync never connects. This picks the hand-rolled
// OAuth loopback flow on Windows and stays out of the way everywhere else,
// where the plugin already works. The conditional import is what keeps
// `dart:io` (and the local web server) out of the web build.
import 'desktop_google_auth_stub.dart'
    if (dart.library.io) 'desktop_google_auth_io.dart' as impl;

import 'package:googleapis/calendar/v3.dart';

import 'desktop_google_tokens.dart';

/// True when this build signs in to Google through the browser loopback flow
/// and a desktop OAuth client is compiled in.
bool get canUseDesktopGoogleFlow => impl.DesktopGoogleAuth.isAvailable;

/// One failure type, so callers do not have to know which platform path ran.
class DesktopGoogleSignInException implements Exception {
  final String message;
  const DesktopGoogleSignInException(this.message);
  @override
  String toString() => message;
}

/// Opens the customer's browser and completes the sign-in. Returns null when
/// the customer closed the tab or declined.
Future<DesktopGoogleTokens?> desktopGoogleSignIn({required String scope}) async {
  try {
    return await impl.DesktopGoogleAuth.signIn(scope: scope);
  } on DesktopGoogleSignInException {
    rethrow;
  } catch (e) {
    throw DesktopGoogleSignInException('$e');
  }
}

/// A usable token, refreshed when needed, or null when not signed in.
Future<DesktopGoogleTokens?> desktopGoogleCredentials() async {
  try {
    return await impl.DesktopGoogleAuth.credentials();
  } catch (_) {
    return null;
  }
}

Future<String?> desktopGoogleEmail() => impl.DesktopGoogleAuth.connectedEmail();

Future<void> desktopGoogleSignOut() => impl.DesktopGoogleAuth.signOut();

/// The Calendar client for the loopback sign-in. Lives in the platform file
/// because building it needs dart:io.
Future<CalendarApi?> desktopGoogleCalendarApi() => impl.DesktopGoogleAuth.calendarApi();
