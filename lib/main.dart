import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/paypaw_app.dart';
import 'core/config/app_config.dart';
import 'core/providers/storage_providers.dart';
import 'features/notifications/domain/services/notification_service.dart';
import 'features/notifications/presentation/controllers/notification_providers.dart';
import 'features/notifications/presentation/controllers/pending_notice.dart';

/// Application entry point.
///
/// Everything that must finish before the first frame happens here, so no
/// widget has to cope with a half-initialised dependency. Anything that can be
/// deferred should be a lazy provider instead of another `await` in this
/// function — each one delays the splash screen.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await _initialiseSupabase();

  final ProviderContainer container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );

  // Before the first frame, and awaited.
  //
  // It has to be awaited because the timezone database is what every scheduled
  // reminder is computed against, and a schedule written before it loads is
  // written in UTC. It is cheap — a database load and two platform calls — and
  // it does *not* ask for permission: a permission dialog on first launch,
  // before the user has seen what the app is for, is the one most reliably
  // refused. Asking belongs with the screen that explains why.
  //
  // A failure here is not fatal. PayPaw without reminders is still a bills
  // tracker; PayPaw that will not start is not.
  await _initialiseNotifications(container);

  runApp(
    UncontrolledProviderScope(container: container, child: const PayPawApp()),
  );
}

/// Brings up the notification machinery: timezones, the plugin, the channels.
Future<void> _initialiseNotifications(ProviderContainer container) async {
  final NotificationService service = container.read(
    notificationServiceProvider,
  );

  try {
    await service.initialize(
      onNoticeTapped: (String payload) =>
          container.read(pendingNoticeProvider.notifier).open(payload),
    );

    // A tap that started the app from cold never reaches the callback above —
    // there was no process to receive it. The plugin holds it as launch details
    // instead, and this is the only way to find out. Read after `initialize`,
    // because before it there is nothing to ask.
    if (await service.noticeThatLaunchedTheApp() case final String payload) {
      container.read(pendingNoticeProvider.notifier).open(payload);
    }
  } on Object catch (error, stackTrace) {
    debugPrint('PayPaw: notifications unavailable ($error)\n$stackTrace');
  }
}

/// Brings up the Supabase client, if it has been configured.
///
/// Skipped entirely when credentials are absent, so the app still runs against
/// no backend — which is how every sprint before authentication was developed.
/// Reading the client in that state throws with a message that says what to do.
Future<void> _initialiseSupabase() async {
  if (!AppConfig.hasSupabaseCredentials) {
    // debugPrint rather than print: it is rate-limited and stripped from
    // release builds, and this is a developer-facing message.
    debugPrint(AppConfig.missingConfigMessage);
    return;
  }

  // Two Supabase defaults matter enough to name, even though neither is passed
  // explicitly here (they are the defaults, and stating them would only be
  // redundant argument noise):
  //
  // * `authFlowType` is PKCE. The implicit flow would return tokens in the
  //   redirect fragment, where any app able to intercept the link can read
  //   them; PKCE returns a single-use code that is worthless without the
  //   verifier held by this app. It is also what makes password recovery work
  //   properly on mobile.
  // * `detectSessionInUri` is true, so an incoming deep link is exchanged for a
  //   session. Without it, tapping a confirmation or reset link opens the app
  //   and nothing happens.
  //
  // If a future SDK version changes either default, this is the place to pin it.
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );
}
