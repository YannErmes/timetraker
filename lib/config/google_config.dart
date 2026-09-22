// Google OAuth for Calendar sync — project calendar-api-for-tracker
// For web, provide via --dart-define GOOGLE_CLIENT_ID or set default here
// For Android, client is auto-detected via google-services.json / SHA-1
const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '671853661004-60v7b026vlb9q8io65kt0iee50tdlk87.apps.googleusercontent.com');
bool get hasGoogleClientId => googleClientId.isNotEmpty;
