import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/config/app_config.dart';

/// Configuration is compiled in with `--dart-define`, so a test run sees the
/// values the *test* build was given — which is none. That makes the
/// unconfigured path the one worth testing, and it happens to be the path most
/// likely to be got wrong: an app that launches, looks fine, and only fails once
/// something touches the backend.
void main() {
  group('without --dart-define values', () {
    test('reports itself as unconfigured', () {
      expect(AppConfig.hasSupabaseCredentials, isFalse);
    });

    test('names every missing key', () {
      expect(AppConfig.missingKeys, <String>[
        'SUPABASE_URL',
        'SUPABASE_PUBLISHABLE_KEY',
      ]);
    });

    test('explains what to do about it', () {
      final String message = AppConfig.missingConfigMessage;

      // The message is what a developer sees in the console when nothing works,
      // so it has to name both the cause and the fix.
      expect(message, contains('SUPABASE_URL'));
      expect(message, contains('SUPABASE_PUBLISHABLE_KEY'));
      expect(message, contains('--dart-define-from-file'));
      expect(message, contains('docs/supabase_setup.md'));
    });
  });

  group('the Android manifest agrees with AppConfig', () {
    // The redirect URL is duplicated in three places: AppConfig, the Android
    // manifest, and the Supabase dashboard. Only two of those are in this
    // repository, so this is the one coupling a test can actually enforce — and
    // a mismatch is invisible until a password-reset link quietly does nothing.
    late final String manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    test('declares the redirect scheme', () {
      expect(
        manifest,
        contains('android:scheme="${AppConfig.authRedirectScheme}"'),
      );
    });

    test('declares the redirect host', () {
      final String host = Uri.parse(AppConfig.authRedirectUrl).host;

      expect(host, isNotEmpty);
      expect(manifest, contains('android:host="$host"'));
    });

    test('keeps the INTERNET permission a release build needs', () {
      // Flutter only adds it to the debug and profile manifests, and Supabase
      // cannot be reached without it.
      expect(manifest, contains('android.permission.INTERNET'));
    });
  });

  group('auth redirect', () {
    test('uses the application ID as its scheme', () {
      // A generic scheme such as "paypaw" could collide with another app on the
      // device; the application ID cannot.
      expect(AppConfig.authRedirectScheme, 'com.paypaw.app');
    });

    test('is the exact string registered in Supabase and the manifest', () {
      // If this changes, three places change together: here, the Android
      // manifest intent filter, and the Supabase dashboard's redirect list.
      // Supabase silently refuses an unlisted redirect, so a mismatch shows up
      // as a password-reset link that does nothing.
      expect(AppConfig.authRedirectUrl, 'com.paypaw.app://login-callback');
    });
  });
}
