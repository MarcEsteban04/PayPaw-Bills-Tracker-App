import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/presentation/widgets/unconfigured_backend_banner.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_controller.dart';
import '../features/auth/presentation/widgets/password_recovery_listener.dart';
import '../features/auth/presentation/widgets/session_expiry_listener.dart';
import '../features/notifications/presentation/controllers/reminder_sync.dart';
import '../features/notifications/presentation/widgets/bill_reminder_listener.dart';
import 'router/app_router.dart';

/// The root widget.
///
/// Deliberately thin: it wires the router, both themes, the canvas behind them,
/// and the one global constraint on text scaling. Startup work belongs in
/// `main()`, and screen logic belongs in its feature.
class PayPawApp extends ConsumerWidget {
  const PayPawApp({super.key});

  /// Lets a message survive the redirect that follows a session expiring.
  ///
  /// `ScaffoldMessenger.of(context)` would be resolved against a navigator that
  /// is about to be replaced; a key held above it is not.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Below this, honouring the setting would only make the app harder to read
  /// without helping anyone — Android's smallest setting is already legible.
  static const double minTextScale = 0.85;

  /// Above this, a screen of dense financial rows stops fitting no matter how
  /// carefully it is laid out.
  ///
  /// Android allows up to 2.0. Clamping is a real accessibility trade-off, taken
  /// deliberately: at 2.0 an amount, a due date and a status chip cannot share a
  /// row, and the honest alternative is a per-screen layout that reflows into a
  /// column — worth building when the real screens exist, and worth revisiting
  /// this number then.
  static const double maxTextScale = 1.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);

    // Watched here and nowhere else, which is the point: the reminder schedule
    // has to follow the bills whether or not any particular screen is on
    // display. Hung off a screen it would stop being rebuilt the moment the user
    // navigated away — and the reminders it failed to cancel would keep firing.
    ref.watch(reminderSyncProvider);

    return MaterialApp.router(
      title: 'PayPaw',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: _buildAppSurface,
    );
  }

  /// Paints the canvas gradient once behind every route, and clamps text scaling
  /// for everything inside it.
  ///
  /// Doing both here rather than per screen is what stops them being
  /// re-declared in every `build` method and drifting apart over 85 sprints.
  ///
  /// The gradient comes from `context.colors`, and this builder runs *below*
  /// `MaterialApp`'s theme — so the canvas follows the active theme with no
  /// branching here. It works because the theme sets `scaffoldBackgroundColor`
  /// to transparent; a screen that genuinely needs an opaque background has to
  /// say so.
  static Widget _buildAppSurface(BuildContext context, Widget? child) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: context.colors.canvas),
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: minTextScale,
        maxScaleFactor: maxTextScale,
        // Outermost of the three, so the warning is above every screen and every
        // listener. In a configured build `wrap` returns its child untouched, so
        // the tree is identical to one without it.
        child: UnconfiguredBackendBanner.wrap(
          // Wraps everything, because a password reset link can arrive while the
          // app is on any screen — or can be what launched it.
          SessionExpiryListener(
            navigatorKey: rootNavigatorKey,
            child: PasswordRecoveryListener(
              // Above the router for the same reason as the two around it: a
              // tapped reminder can arrive on any screen, or before there is
              // one at all when the notification is what started the app.
              child: BillReminderListener(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
