// Google OAuth for Calendar sync — simplest direct from Flutter
// Provide via --dart-define GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com for web
// For Android, client is auto-detected via google-services.json / SHA-1, so this can be empty
const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '');
bool get hasGoogleClientId => googleClientId.isNotEmpty;
