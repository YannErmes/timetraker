// Supabase project values.
//
// The key below is a PUBLISHABLE key (sb_publishable_...). It is a public
// client key by design - it ships inside every app/web bundle and row level
// security is the actual access boundary, so there is nothing secret here.
//
// These are compiled in on purpose: an *empty* --dart-define used to be
// treated as "configured" (because '' does not contain the placeholder text),
// so a build with blank CI variables booted straight into a dead cloud and
// failed with "Invalid API key 401" instead of the demo banner. Compiling the
// values in, and rejecting empty ones, removes that entire failure mode.
// No build step passes --dart-define any more.
//
// To point the app at a different project, change the two values below.
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://iahdnivrfgdocdztrcnc.supabase.co');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_q-MdstOgxZQtxKwz-iayrw_S2-hT-yy');

bool get isSupabaseConfigured =>
    supabaseUrl.isNotEmpty &&
    supabaseAnonKey.isNotEmpty &&
    supabaseUrl.startsWith('http') &&
    !supabaseUrl.contains('YOUR_PROJECT') &&
    !supabaseAnonKey.contains('YOUR_ANON_KEY');

/// Short, non-secret fingerprint of the key so a wrong/blank/rotated key is
/// visible in the UI instead of showing up as a mysterious 401.
String get supabaseKeyLabel {
  final k = supabaseAnonKey.trim();
  if (k.isEmpty) return 'key: <empty>';
  if (k.contains('YOUR_ANON_KEY')) return 'key: <placeholder>';
  if (k.startsWith('sb_publishable_')) return 'key: sb_publishable_…';
  if (k.startsWith('eyJ')) return 'key: legacy JWT (anon)';
  return 'key: ${k.length} chars, unrecognised';
}
