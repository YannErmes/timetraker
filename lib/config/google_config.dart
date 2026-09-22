// Google OAuth for Calendar sync — simplest direct from Flutter
// For web, provide via --dart-define GOOGLE_CLIENT_ID or set default here
// For Android, client is auto-detected via google-services.json / SHA-1
const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '640926549822-1p41md26k53bvajuh40pto6vl6m68ree.apps.googleusercontent.com');
bool get hasGoogleClientId => googleClientId.isNotEmpty;
