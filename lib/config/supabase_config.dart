// Replace with your Supabase project values.
// For local dev you can set --dart-define SUPABASE_URL=... SUPABASE_ANON_KEY=...
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://YOUR_PROJECT.supabase.co');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'YOUR_ANON_KEY');
bool get isSupabaseConfigured => !supabaseUrl.contains('YOUR_PROJECT') && !supabaseAnonKey.contains('YOUR_ANON_KEY');
