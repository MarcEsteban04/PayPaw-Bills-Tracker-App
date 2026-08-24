import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/config/app_config.dart';

/// Both Supabase keys sit side by side in the dashboard, and in a `.env` file
/// they are two lines apart. A secret or service-role key in a client build
/// bypasses **every** RLS policy in the database — so the distance between a typo
/// and a total data breach is exactly this check.
void main() {
  /// Builds a JWT-shaped string carrying [payload] as its middle segment.
  String jwtWith(Map<String, Object?> payload) {
    String encode(Map<String, Object?> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

    final String header = encode(<String, Object?>{'alg': 'HS256'});

    return '$header.${encode(payload)}.signature';
  }

  group('recognises a secret key', () {
    test('in the current format', () {
      expect(AppConfig.keyLooksSecret('sb_secret_abc123'), isTrue);
    });

    test('in the legacy JWT format', () {
      expect(
        AppConfig.keyLooksSecret(
          jwtWith(<String, Object?>{'role': 'service_role', 'iss': 'supabase'}),
        ),
        isTrue,
      );
    });
  });

  group('accepts a key that is meant to ship', () {
    test('the current publishable format', () {
      expect(AppConfig.keyLooksSecret('sb_publishable_abc123'), isFalse);
    });

    test('a legacy anon JWT', () {
      expect(
        AppConfig.keyLooksSecret(
          jwtWith(<String, Object?>{'role': 'anon', 'iss': 'supabase'}),
        ),
        isFalse,
      );
    });
  });

  group('is conservative about what it cannot read', () {
    test('an unrecognisable key is opaque, not secret', () {
      // Refusing to start on a valid-but-unfamiliar key would be its own outage,
      // so anything undecodable is treated as "not proven secret".
      for (final String key in <String>['not-a-jwt', 'a.b.c', 'x.y', '']) {
        expect(
          AppConfig.keyLooksSecret(key),
          isFalse,
          reason: '"$key" should not be reported as secret',
        );
      }
    });

    test('a JWT with no role claim is not secret', () {
      expect(
        AppConfig.keyLooksSecret(jwtWith(<String, Object?>{'iss': 'supabase'})),
        isFalse,
      );
    });
  });

  group('how the app reacts', () {
    test('a secret key counts as unconfigured', () {
      // Deliberately not "configured but wrong". Reporting it as unconfigured
      // routes the app down the no-backend path every screen already handles,
      // instead of connecting with credentials that defeat every policy.
      //
      // The test build has no defines, so both are false here; the wiring is what
      // this pins — hasSupabaseCredentials consults hasSecretKeyMistake at all.
      expect(AppConfig.hasSecretKeyMistake, isFalse);
      expect(AppConfig.hasSupabaseCredentials, isFalse);
    });

    test('the message names the mistake and the fix', () {
      // Read by whoever built the app with the wrong key, so it has to say which
      // key to use and where to find it.
      final String message = AppConfig.missingConfigMessage;

      expect(message, contains('SUPABASE_PUBLISHABLE_KEY'));
    });
  });
}
