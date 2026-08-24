import 'dart:convert';

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

  /// Whether the configured key is a **secret** key that must never ship.
  ///
  /// A service-role or secret key bypasses row level security entirely: with one,
  /// every account can read and write every other account's data, and no policy
  /// in the database can stop it. It belongs in an Edge Function or a server,
  /// never in a build that reaches a device.
  ///
  /// This is not a hypothetical mix-up. Both keys sit side by side in the
  /// dashboard, and in a `.env` file they are two lines apart.
  static bool get hasSecretKeyMistake => keyLooksSecret(supabasePublishableKey);

  /// Whether [key] is a Supabase **secret** key rather than a publishable one.
  ///
  /// Covers both formats:
  ///
  /// * the current one, which is prefixed `sb_secret_`;
  /// * the legacy one, a JWT whose payload claims `role: service_role`.
  ///
  /// Conservative by design: anything it cannot decode is treated as *not*
  /// secret, because refusing to start on an unrecognised-but-valid key would be
  /// its own outage. It is a guard against the obvious mistake, not a substitute
  /// for care.
  static bool keyLooksSecret(String key) {
    if (key.isEmpty) {
      return false;
    }
    if (key.startsWith('sb_secret_')) {
      return true;
    }

    // Legacy keys are JWTs: header.payload.signature. Only the payload matters,
    // and it is base64url without padding.
    final List<String> segments = key.split('.');
    if (segments.length != 3) {
      return false;
    }

    try {
      final String payload = utf8.decode(
        base64Url.decode(base64Url.normalize(segments[1])),
      );
      final Object? decoded = jsonDecode(payload);

      return decoded is Map<String, dynamic> &&
          decoded['role'] == 'service_role';
    } on Object {
      // Not decodable as a JWT payload. Treat as opaque rather than as secret.
      return false;
    }
  }

  /// Whether every required Supabase value was supplied, and none of them is a
  /// key that must not be here.
  ///
  /// A secret key counts as *not configured* rather than as configured-and-wrong,
  /// so the app falls back to the no-backend path the rest of the code already
  /// handles instead of connecting with credentials that defeat every policy.
  static bool get hasSupabaseCredentials =>
      missingKeys.isEmpty && !hasSecretKeyMistake;

  /// A message worth printing at startup when configuration is incomplete.
  ///
  /// Spelled out rather than terse, because the failure it explains — an app that
  /// launches, looks fine, and then throws the moment anything touches the
  /// backend — is otherwise a confusing half hour.
  static String get missingConfigMessage {
    if (hasSecretKeyMistake) {
      return 'PayPaw refused to start Supabase: SUPABASE_PUBLISHABLE_KEY is a '
          'SECRET key. A secret or service-role key bypasses row level security '
          'entirely and must never ship in a client build. Use the publishable '
          'key (sb_publishable_...) from Project Settings > API keys. See '
          'docs/security.md.';
    }

    return 'PayPaw started without Supabase configuration. '
        'Missing: ${missingKeys.join(', ')}. '
        'The app will run, but anything that reads the Supabase client will throw. '
        'Pass --dart-define-from-file=config/dev.json; '
        'see docs/supabase_setup.md.';
  }
}
