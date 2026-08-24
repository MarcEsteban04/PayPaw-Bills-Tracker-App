import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_toast.dart';
import '../controllers/session_expiry_provider.dart';

/// Explains an unasked-for sign-out.
///
/// The route guard already sends the user back to sign-in when a session ends.
/// What it cannot do is say *why* — and being returned to a sign-in screen with
/// no explanation reads as the app losing your work.
///
/// Only fires for sessions that ended on their own. An explicit sign-out needs no
/// commentary; announcing it would be telling the user what they just did.
class SessionExpiryListener extends ConsumerWidget {
  const SessionExpiryListener({
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  /// The router's navigator, because this widget wraps it from inside
  /// `MaterialApp`'s builder and so has no `Overlay` in its own context.
  ///
  /// The message also has to survive the redirect that follows it, which is what
  /// rules out anything owned by the route being left.
  final GlobalKey<NavigatorState> navigatorKey;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<int>>(sessionExpiryProvider, (
      AsyncValue<int>? previous,
      AsyncValue<int> next,
    ) {
      if (next case AsyncData<int>()) {
        // The navigator's *overlay*, handed over directly. Looking upward from
        // the navigator's own context finds nothing, because the overlay is its
        // child.
        if (navigatorKey.currentState?.overlay
            case final OverlayState overlay) {
          showAppToast(
            context,
            overlay: overlay,
            message: 'Your session expired. Please sign in again.',
            tone: AppToastTone.error,
          );
        }
      }
    });

    return child;
  }
}
