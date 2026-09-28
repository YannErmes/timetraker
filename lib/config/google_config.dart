// Google OAuth for Calendar sync — project calendar-api-for-tracker
// For web, provide via --dart-define GOOGLE_CLIENT_ID or set default here
// For Android, client is auto-detected via google-services.json / SHA-1
const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '671853661004-60v7b026vlb9q8io65kt0iee50tdlk87.apps.googleusercontent.com');
bool get hasGoogleClientId => googleClientId.isNotEmpty;

// Windows sign-in. The google_sign_in plugin has no Windows implementation, so
// the EXE does the OAuth loopback flow itself (browser -> http://localhost:8787
// -> code -> tokens). For that Google needs a *Desktop app* OAuth client in the
// same project, with this redirect URI registered under
// "Authorized redirect URIs":
//
//     http://localhost:8787/oauth2callback
//
// Paste its id and secret here (or pass them with --dart-define). A desktop
// client secret ships inside the app on purpose: Google does not treat it as
// confidential, and it cannot keep one out of a binary the customer owns.
const String googleDesktopClientId = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID', defaultValue: '');
const String googleDesktopClientSecret = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET', defaultValue: '');
bool get hasGoogleDesktopClient => googleDesktopClientId.isNotEmpty && googleDesktopClientSecret.isNotEmpty;
