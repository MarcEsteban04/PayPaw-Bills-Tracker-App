import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/paypaw_app.dart';
import 'core/config/app_config.dart';
import 'core/providers/storage_providers.dart';

/// Application entry point.
///
/// Everything that must finish before the first frame happens here, so no
/// widget has to cope with a half-initialised dependency. Anything that can be
/// deferred should be a lazy provider instead of another `await` in this
/// function — each one delays the splash screen.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SharedPreferences preferences = await SharedPreferences.getInstance();

  // Supabase is skipped until the project exists and its credentials are passed
  // with --dart-define. The app still runs; anything that reads the client
  // throws a clear error rather than failing silently.
  if (AppConfig.hasSupabaseCredentials) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const PayPawApp(),
    ),
  );
}
