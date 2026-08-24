import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/router/app_routes.dart';
import '../controllers/password_recovery_provider.dart';

/// Sends the user to the new-password screen when a reset link is opened.
///
/// Wrapped around the whole app rather than placed on a screen, because a reset
/// link can arrive at any moment — while the user is on the dashboard, on the
/// sign-in screen, or as the thing that launched the app in the first place.
///
/// Navigates through the router provider rather than `context`, so it does not
/// depend on where in the tree it happens to sit.
class PasswordRecoveryListener extends ConsumerWidget {
  const PasswordRecoveryListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<int>>(passwordRecoveryProvider, (
      AsyncValue<int>? previous,
      AsyncValue<int> next,
    ) {
      if (next case AsyncData<int>()) {
        ref.read(routerProvider).goNamed(AppRoutes.resetPassword.routeName);
      }
    });

    return child;
  }
}
