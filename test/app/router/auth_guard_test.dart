import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/app/router/app_routes.dart';
import 'package:paypaw/app/router/auth_guard.dart';
import 'package:paypaw/features/auth/domain/entities/authenticated_user.dart';

/// The guard decides what an unauthenticated stranger can reach, so it gets the
/// thorough treatment. It is a pure function precisely so this is cheap.
void main() {
  const AuthenticatedUser marc = AuthenticatedUser(
    id: 'user-1',
    email: 'marc@example.com',
    hasConfirmedEmail: true,
  );

  const AsyncValue<AuthenticatedUser?> signedIn = AsyncData<AuthenticatedUser?>(
    marc,
  );
  const AsyncValue<AuthenticatedUser?> signedOut =
      AsyncData<AuthenticatedUser?>(null);
  const AsyncValue<AuthenticatedUser?> unknown =
      AsyncLoading<AuthenticatedUser?>();

  String? redirect({
    required AsyncValue<AuthenticatedUser?> session,
    required AppRoutes to,
    bool configured = true,
  }) => authRedirect(
    isBackendConfigured: configured,
    session: session,
    location: to.path,
  );

  group('without a backend', () {
    test('nothing is guarded', () {
      // There is no session and never will be, so guarding would trap the user
      // on a sign-in screen that cannot work. Every sprint before this one ran
      // this way.
      for (final AppRoutes route in AppRoutes.values) {
        expect(
          redirect(session: signedOut, to: route, configured: false),
          isNull,
          reason: '${route.name} should be reachable without a backend',
        );
      }
    });
  });

  group('while the session is still unknown', () {
    test('nobody is redirected', () {
      // Redirecting on a guess would flash the sign-in screen at an already
      // signed-in user on every cold start.
      expect(redirect(session: unknown, to: AppRoutes.dashboard), isNull);
      expect(redirect(session: unknown, to: AppRoutes.signIn), isNull);
    });
  });

  group('signed out', () {
    test('protected routes send you to sign-in', () {
      for (final AppRoutes route in <AppRoutes>[
        AppRoutes.dashboard,
        AppRoutes.bills,
        AppRoutes.calendar,
        AppRoutes.profile,
        AppRoutes.designSystem,
        AppRoutes.components,
      ]) {
        expect(
          redirect(session: signedOut, to: route),
          AppRoutes.signIn.path,
          reason: '${route.name} should require a session',
        );
      }
    });

    test('the auth screens are reachable', () {
      for (final AppRoutes route in publicRoutes) {
        expect(
          redirect(session: signedOut, to: route),
          isNull,
          reason: '${route.name} should be public',
        );
      }
    });
  });

  group('signed in', () {
    test('the app is reachable', () {
      expect(redirect(session: signedIn, to: AppRoutes.dashboard), isNull);
      expect(redirect(session: signedIn, to: AppRoutes.bills), isNull);
      expect(redirect(session: signedIn, to: AppRoutes.profile), isNull);
    });

    test('the auth screens bounce back to the dashboard', () {
      for (final AppRoutes route in <AppRoutes>[
        AppRoutes.signIn,
        AppRoutes.signUp,
        AppRoutes.forgotPassword,
      ]) {
        expect(
          redirect(session: signedIn, to: route),
          AppRoutes.dashboard.path,
          reason: '${route.name} should not be shown to a signed-in user',
        );
      }
    });

    test('reset-password is exempt from that bounce', () {
      // The exception that makes password recovery possible at all. Opening a
      // reset link creates a recovery session, so the user IS signed in by the
      // time this screen appears. Bouncing them would mean the guard breaks the
      // flow it is meant to protect, and the password could never be changed.
      expect(redirect(session: signedIn, to: AppRoutes.resetPassword), isNull);
    });
  });

  group('when the session cannot be read', () {
    const AsyncValue<AuthenticatedUser?> broken =
        AsyncError<AuthenticatedUser?>('boom', StackTrace.empty);

    test('it counts as signed out', () {
      // Fail closed. A guard that opens up when it cannot tell is not a guard.
      expect(
        redirect(session: broken, to: AppRoutes.dashboard),
        AppRoutes.signIn.path,
      );
    });

    test('but the auth screens still work', () {
      // Otherwise the user cannot sign in to fix it.
      expect(redirect(session: broken, to: AppRoutes.signIn), isNull);
    });
  });
}
