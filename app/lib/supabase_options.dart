// Supabase configuration for the RakshaPay Android app.
//
// Nothing is hardcoded here. Both values are injected at build time and the
// file that holds them (app/env.json) is gitignored, so no key ever reaches the
// repository:
//
//   flutter run   --dart-define-from-file=env.json
//   flutter build apk --dart-define-from-file=env.json
//
// Copy env.example.json to env.json and fill it in. Without it the app still
// builds and runs — it simply has no community sync, which is the correct
// degradation for an offline-first app.
//
// Only ever put the PUBLISHABLE key here. A service_role/secret key bypasses
// every Row Level Security policy in backend/supabase/schema.sql.
class SupabaseOptions {
  static const String url = String.fromEnvironment('SUPABASE_URL');

  static const String publishableKey = String.fromEnvironment('SUPABASE_KEY');

  /// Lets the app boot and score payments even when the backend is not wired
  /// up. Everything that matters runs on-device, so a missing backend must
  /// degrade to "no community sync", never to "app won't start".
  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
