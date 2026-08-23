/// Compile-time configuration for PayPaw.
///
/// Values are injected with `--dart-define` so that no credential is ever
/// committed to the repository:
///
/// ```sh
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<project>.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
/// ```
///
/// Until the Supabase project exists, both values are empty and the app runs
/// without a backend. Use [hasSupabaseCredentials] to branch on that instead of
/// comparing the strings at call sites.
abstract final class AppConfig {
  /// Base URL of the Supabase project.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase publishable (public) API key.
  ///
  /// This key is safe to ship in a client build — row level security, not
  /// secrecy, is what protects the data. Supabase renamed this from the older
  /// 'anon key'; the SDK now takes it as `publishableKey`.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Whether both Supabase values were supplied at build time.
  static bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
