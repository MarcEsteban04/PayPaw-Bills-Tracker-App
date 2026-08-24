import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_controller.dart';
import '../features/auth/presentation/widgets/password_recovery_listener.dart';
import 'router/app_router.dart';

/// The root widget.
///
/// Deliberately thin: it wires the router, both themes, the canvas behind them,
/// and the one global constraint on text scaling. Startup work belongs in
/// `main()`, and screen logic belongs in its feature.
class PayPawApp extends ConsumerWidget {
  const PayPawApp({super.key});

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

    return MaterialApp.router(
      title: 'PayPaw',
      debugShowCheckedModeBanner: false,
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
        // Wraps everything, because a password reset link can arrive while the
        // app is on any screen — or can be what launched it.
        child: PasswordRecoveryListener(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
