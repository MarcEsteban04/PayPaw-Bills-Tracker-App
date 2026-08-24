import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/entities/authenticated_user.dart';
import 'app_routes.dart';

/// Routes reachable without a session.
///
/// Everything else needs one. Kept as a set of [AppRoutes] rather than raw
/// strings so a renamed path cannot quietly fall out of the list.
const Set<AppRoutes> publicRoutes = <AppRoutes>{
  AppRoutes.signIn,
  AppRoutes.signUp,
  AppRoutes.forgotPassword,
  AppRoutes.resetPassword,
};

/// Where the user should be sent, or null to leave them where they are.
///
/// A pure function on purpose: route guards are exactly the kind of logic that
/// is painful to test through a widget tree and trivial to test directly.
///
/// ## The three rules
///
/// 1. **No backend, no guarding.** Without Supabase configuration there is no
///    session and never will be, so guarding would trap the user on a sign-in
///    screen that cannot work. The app runs unguarded instead, which is what
///    every sprint before this one relied on.
/// 2. **Never decide before the answer is known.** While the session is still
///    loading this returns null. Redirecting on a guess would flash the sign-in
///    screen at an already signed-in user on every cold start.
/// 3. **An error counts as signed out.** If the session cannot be read, the safe
///    reading is "not authenticated" — a guard that fails open is not a guard.
///
/// ## The exception that matters
///
/// A signed-in user is bounced off the auth screens, **except
/// `/reset-password`**. Opening a reset link creates a recovery session, so by
/// the time that screen appears the user *is* signed in. Without this exception
/// the guard would send them to the dashboard and password recovery could never
/// complete — the flow would be broken by the code meant to protect it.
String? authRedirect({
  required bool isBackendConfigured,
  required AsyncValue<AuthenticatedUser?> session,
  required String location,
}) {
  if (!isBackendConfigured) {
    return null;
  }

  final bool isPublic = publicRoutes.any(
    (AppRoutes route) => route.path == location,
  );

  // Rule 3: fail closed.
  if (session case AsyncError<AuthenticatedUser?>()) {
    return isPublic ? null : AppRoutes.signIn.path;
  }

  // Rule 2: not yet known.
  if (!session.hasValue) {
    return null;
  }

  final bool isSignedIn = session.value != null;

  if (!isSignedIn) {
    return isPublic ? null : AppRoutes.signIn.path;
  }

  if (isPublic && location != AppRoutes.resetPassword.path) {
    return AppRoutes.dashboard.path;
  }

  return null;
}
