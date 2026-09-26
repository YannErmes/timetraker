// Supabase project values. The anon key is a PUBLIC key by design (it ships
// in every web client - row level security is the real access boundary), so it
// lives here as a default exactly like the Google client id. That keeps every
// build configured: Vercel, the Windows/iOS runners and local dev.
// A build can still override them:
//   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://iahdnivrfgdocdztrcnc.supabase.co');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlhaGRuaXZyZmdkb2NkenRyY25jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxMDA2NDQsImV4cCI6MjEwNTY3NjY0NH0.4j6SHTCKMtVtmUYd9NJ2N7kaW0OMWHy6pHLs1BGMPS4');
bool get isSupabaseConfigured =>
    supabaseUrl.isNotEmpty &&
    supabaseAnonKey.isNotEmpty &&
    !supabaseUrl.contains('YOUR_PROJECT') &&
    !supabaseAnonKey.contains('YOUR_ANON_KEY');
