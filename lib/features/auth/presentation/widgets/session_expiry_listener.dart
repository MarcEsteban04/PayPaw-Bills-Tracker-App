import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    required this.messengerKey,
    required this.child,
    super.key,
  });

  /// Used instead of `ScaffoldMessenger.of(context)`, because this widget sits
  /// above the navigator and the message has to survive the redirect that
  /// follows it.
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<int>>(sessionExpiryProvider, (
      AsyncValue<int>? previous,
      AsyncValue<int> next,
    ) {
      if (next case AsyncData<int>()) {
        messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Your session expired. Please sign in again.'),
            ),
          );
      }
    });

    return child;
  }
}
