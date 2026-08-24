import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Who is signed in, kept current.
///
/// A stream rather than a value read at startup: a session can end without the
/// user asking — a refresh token expires, or it is revoked from another device —
/// and the app has to notice rather than showing a signed-in shell that cannot
/// load anything.
///
/// Sprint 15 builds the route guards on top of this.
final StreamProvider<AuthenticatedUser?>
currentUserProvider = StreamProvider<AuthenticatedUser?>((Ref ref) {
  // Without a configured backend there is no session to observe, and reading
  // the repository would throw. An unconfigured app is signed out, which is
  // the truthful answer and keeps every screen above this working.
  if (!ref.watch(isBackendConfiguredProvider)) {
    return Stream<AuthenticatedUser?>.value(null);
  }

  return _sessions(ref.watch(authRepositoryProvider));
});

/// The restored session first, then every change to it.
///
/// Yielding [AuthRepository.currentUser] up front means the first frame has an
/// answer instead of a loading state — which is what stops an already
/// signed-in user seeing a flash of the sign-in screen on launch.
Stream<AuthenticatedUser?> _sessions(AuthRepository repository) async* {
  yield repository.currentUser;
  yield* repository.authStateChanges();
}
