import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'current_user_provider.dart';

/// Bridges the session stream to go_router.
///
/// `GoRouter` re-runs its `redirect` when a `Listenable` it was given notifies.
/// This is that listenable, driven by `currentUserProvider`.
///
/// The bridge exists because the alternative is worse: watching the session
/// inside the router provider would rebuild the whole `GoRouter` on every auth
/// change, discarding the navigation stack with it. A notifier lets the router
/// stay put and simply re-evaluate where the user is allowed to be.
class AuthRefreshNotifier extends ChangeNotifier {
  /// Tells go_router to re-run its guard.
  void refresh() => notifyListeners();
}

/// The listenable handed to `GoRouter.refreshListenable`.
///
/// Deliberately never rebuilt, so the router is never rebuilt either.
final Provider<AuthRefreshNotifier> authRefreshProvider =
    Provider<AuthRefreshNotifier>((Ref ref) {
      final AuthRefreshNotifier notifier = AuthRefreshNotifier();

      ref.listen(currentUserProvider, (_, _) => notifier.refresh());
      ref.onDispose(notifier.dispose);

      return notifier;
    });
