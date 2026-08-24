import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/entities/authenticated_user.dart';
import '../../features/onboarding/domain/repositories/onboarding_progress_store.dart';
import 'app_routes.dart';

/// Routes reachable without a session.
///
/// Everything else needs one. Kept as a set of [AppRoutes] rather than raw
/// strings so a renamed path cannot quietly fall out of the list.
const Set<AppRoutes> publicRoutes = <AppRoutes>{
  AppRoutes.welcome,
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
/// ## The rules that always apply
///
/// 1. **No backend, no guarding.** Without Supabase configuration there is no
///    session and never will be, so guarding would trap the user on a sign-in
///    screen that cannot work. The app runs unguarded instead.
/// 2. **Never decide before the answer is known.** While the session is still
///    loading this returns null. Redirecting on a guess would flash the sign-in
///    screen at an already signed-in user on every cold start.
/// 3. **An error counts as signed out.** If the session cannot be read, the safe
///    reading is "not authenticated" — a guard that fails open is not a guard.
///
/// ## Signed out
///
/// A first install goes to `/welcome` before anything else, once. After that,
/// public routes are left alone and everything else goes to `/sign-in`.
///
/// ## Signed in
///
/// `/reset-password` is checked **first, before onboarding**. Opening a reset
/// link creates a recovery session, so the user arrives signed in — and if
/// onboarding were checked first, someone resetting their password on a new
/// device would be sent to a setup form instead of the field they came to fill
/// in, with no way to reach it. Recovery outranks setup.
///
/// Then onboarding: an account that has not been through it is sent there, from
/// wherever it landed. It is per-account rather than per-install, so a second
/// account on a shared phone is asked its own preferences instead of inheriting
/// the first one's.
///
/// Finally, a signed-in user is bounced off the auth screens.
String? authRedirect({
  required bool isBackendConfigured,
  required AsyncValue<AuthenticatedUser?> session,
  required String location,
  required OnboardingProgressStore progress,
}) {
  if (!isBackendConfigured) {
    return null;
  }

  final bool isPublic = publicRoutes.any(
    (AppRoutes route) => route.path == location,
  );

  // Rule 3: fail closed. An unreadable session is a signed-out one, and a
  // first-run install still deserves the welcome screen.
  if (session case AsyncError<AuthenticatedUser?>()) {
    return _signedOutDestination(
      location: location,
      isPublic: isPublic,
      progress: progress,
    );
  }

  // Rule 2: not yet known.
  if (!session.hasValue) {
    return null;
  }

  final AuthenticatedUser? user = session.value;

  if (user == null) {
    return _signedOutDestination(
      location: location,
      isPublic: isPublic,
      progress: progress,
    );
  }

  // Password recovery outranks everything below. See the doc comment.
  if (location == AppRoutes.resetPassword.path) {
    return null;
  }

  if (!progress.hasCompletedOnboarding(user.id)) {
    return location == AppRoutes.onboarding.path
        ? null
        : AppRoutes.onboarding.path;
  }

  if (isPublic) {
    return AppRoutes.dashboard.path;
  }

  return null;
}

String? _signedOutDestination({
  required String location,
  required bool isPublic,
  required OnboardingProgressStore progress,
}) {
  if (!progress.hasSeenWelcome) {
    return location == AppRoutes.welcome.path ? null : AppRoutes.welcome.path;
  }

  return isPublic ? null : AppRoutes.signIn.path;
}
