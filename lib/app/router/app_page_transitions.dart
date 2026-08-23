import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Route transitions.
///
/// Two rules, both deliberate:
///
/// * **Switching tabs does not animate.** The four primary destinations are
///   siblings, not a hierarchy, and `StatefulShellRoute.indexedStack` swaps them
///   instantly. Sliding between peers implies a direction that does not exist.
/// * **Pushing a detail slides in from the right.** That is a move *deeper*, and
///   the motion is what tells the user a back gesture will undo it.
///
/// Durations are short on purpose. Navigation animation is feedback, not
/// decoration; past roughly 300ms it starts to feel like waiting.
///
/// All of it is skipped when the platform reports that animations are disabled —
/// Android's "Remove animations" accessibility setting. Motion sensitivity is a
/// real condition, and an app that animates anyway is one the setting does not
/// work on.
abstract final class AppPageTransitions {
  static const Duration _duration = Duration(milliseconds: 240);
  static const Duration _reverseDuration = Duration(milliseconds: 200);

  /// A detail pushed on top of the current screen: slides in from the right
  /// while fading, and the reverse on the way out.
  static CustomTransitionPage<void> forward({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: _duration,
      reverseTransitionDuration: _reverseDuration,
      child: child,
      transitionsBuilder: _slideAndFade,
    );
  }

  /// A screen that replaces the current one without implying depth — an auth
  /// gate, a splash hand-off. Fades only.
  static CustomTransitionPage<void> fade({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: _duration,
      reverseTransitionDuration: _reverseDuration,
      child: child,
      transitionsBuilder: _fadeOnly,
    );
  }

  static Widget _fadeOnly(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    return FadeTransition(opacity: animation, child: child);
  }

  static Widget _slideAndFade(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    final Animation<double> eased = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).animate(eased),
      child: FadeTransition(opacity: eased, child: child),
    );
  }
}
