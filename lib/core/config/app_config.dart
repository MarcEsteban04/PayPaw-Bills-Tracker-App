/// Compile-time configuration for PayPaw.
///
/// Values arrive through `--dart-define`, so no credential is ever committed.
/// In practice they come from a JSON file rather than typed on the command line:
///
/// ```sh
/// flutter run --dart-define-from-file=config/dev.json
/// ```
///
/// `config/dev.json` is gitignored; `config/dev.example.json` shows its shape.
/// See `docs/supabase_setup.md` for how to fill it in.
///
/// Until the Supabase project exists both values are empty and the app runs
/// without a backend. Branch on [hasSupabaseCredentials] rather than comparing
/// the strings at call sites.
abstract final class AppConfig {
  /// Base URL of the Supabase project, e.g. `https://abcdefg.supabase.co`.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase publishable (public) API key.
  ///
  /// Safe to ship in a client build — row level security, not secrecy, is what
  /// protects the data. Supabase renamed this from the older 'anon key'; the SDK
  /// takes it as `publishableKey`.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Custom scheme PayPaw registers for auth deep links.
  ///
  /// Matches the Android application ID so it cannot collide with another app's
  /// scheme on the device.
  static const String authRedirectScheme = 'com.paypaw.app';

  /// Where Supabase sends the user back to after an email confirmation, a
  /// password reset, or an OAuth sign-in.
  ///
  /// This exact string has to be listed under **Authentication → URL
  /// Configuration → Redirect URLs** in the Supabase dashboard. Supabase refuses
  /// any redirect that is not on that list, and the resulting failure is silent
  /// from the app's side — the link simply never comes back.
  static const String authRedirectUrl = '$authRedirectScheme://login-callback';

  /// Names of the required values that were not supplied, in the order they
  /// should be fixed.
  static List<String> get missingKeys => <String>[
    if (supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
  ];

  /// Whether every required Supabase value was supplied at build time.
  static bool get hasSupabaseCredentials => missingKeys.isEmpty;

  /// A message worth printing at startup when configuration is incomplete.
  ///
  /// Spelled out rather than terse, because the failure it explains — an app that
  /// launches, looks fine, and then throws the moment anything touches the
  /// backend — is otherwise a confusing half hour.
  static String get missingConfigMessage =>
      'PayPaw started without Supabase configuration. '
      'Missing: ${missingKeys.join(', ')}. '
      'The app will run, but anything that reads the Supabase client will throw. '
      'Pass --dart-define-from-file=config/dev.json; '
      'see docs/supabase_setup.md.';
}
