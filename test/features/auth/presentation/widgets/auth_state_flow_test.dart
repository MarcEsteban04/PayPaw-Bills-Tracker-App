import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/app/paypaw_app.dart';
import 'package:paypaw/app/shell/app_destination.dart';
import 'package:paypaw/core/providers/storage_providers.dart';
import 'package:paypaw/core/providers/supabase_providers.dart';
import 'package:paypaw/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:paypaw/features/auth/domain/entities/authenticated_user.dart';
import 'package:paypaw/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:paypaw/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:paypaw/features/onboarding/presentation/controllers/onboarding_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_onboarding_progress.dart';
import '../../helpers/fake_auth_repository.dart';

/// Authentication state, driven through the whole app.
///
/// The guard is unit-tested as a pure function elsewhere; this checks it is
/// actually wired to the router, that the session survives a restart, and that
/// an expiring session both redirects and explains itself.
void main() {
  const AuthenticatedUser marc = AuthenticatedUser(
    id: 'user-1',
    email: 'marc@example.com',
    hasConfirmedEmail: true,
  );

  /// First-run state defaults to a returning, set-up user, so these tests keep
  /// describing authentication rather than onboarding. The two first-run cases
  /// say otherwise explicitly, at the bottom of this file.
  Future<void> pumpApp(
    WidgetTester tester,
    FakeAuthRepository repository, {
    bool hasSeenWelcome = true,
    bool onboarded = true,
  }) async {
    addTearDown(repository.dispose);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          isBackendConfiguredProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(repository),
          onboardingProgressStoreProvider.overrideWithValue(
            FakeOnboardingProgress(
              hasSeenWelcome: hasSeenWelcome,
              onboarded: onboarded ? <String>{marc.id} : <String>{},
            ),
          ),
        ],
        child: const PayPawApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('automatic login', () {
    testWidgets('a stored session opens straight into the app', (
      WidgetTester tester,
    ) async {
      // What "persist sessions" and "automatic login" amount to from the user's
      // side: relaunching does not ask again.
      await pumpApp(tester, FakeAuthRepository(initialUser: marc));

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
    });

    testWidgets('no session lands on sign-in instead', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository());

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
    });
  });

  group('protected routes', () {
    testWidgets('the tabs are unreachable without a session', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository());

      // There is no navigation bar to tap: the guard redirected before the shell
      // was ever built.
      expect(find.bySemanticsLabel(AppDestination.bills.label), findsNothing);
    });

    testWidgets('and reachable with one', (WidgetTester tester) async {
      await pumpApp(tester, FakeAuthRepository(initialUser: marc));

      await tester.tap(find.bySemanticsLabel(AppDestination.bills.label));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Bills'), findsOneWidget);
    });
  });

  group('signing out', () {
    testWidgets('confirms, then returns to sign-in', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository(
        initialUser: marc,
      );
      await pumpApp(tester, repository);

      await tester.tap(find.bySemanticsLabel(AppDestination.profile.label));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
      await tester.pumpAndSettle();

      // Confirmed first: signing out is disruptive, and one stray tap away.
      expect(find.text('Sign out?'), findsOneWidget);
      expect(repository.signOutCalls, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 1);
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('cancelling keeps the session', (WidgetTester tester) async {
      final FakeAuthRepository repository = FakeAuthRepository(
        initialUser: marc,
      );
      await pumpApp(tester, repository);

      await tester.tap(find.bySemanticsLabel(AppDestination.profile.label));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 0);
      expect(find.text('marc@example.com'), findsOneWidget);
    });
  });

  group('session expiry', () {
    testWidgets('redirects to sign-in and says why', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository(
        initialUser: marc,
      );
      await pumpApp(tester, repository);
      expect(find.byType(DashboardScreen), findsOneWidget);

      // A refresh token rejected, or revoked from another device.
      repository.emitSessionExpiry();
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      // Being returned to a sign-in screen with no explanation reads as the app
      // losing your work.
      expect(
        find.text('Your session expired. Please sign in again.'),
        findsOneWidget,
      );
    });
  });

  group('first run, through the whole app', () {
    testWidgets('a fresh install opens on the welcome screen', (
      WidgetTester tester,
    ) async {
      // Not the dashboard, and not sign-in either: someone who has never seen
      // the app is told what it is before being asked to make an account.
      await pumpApp(tester, FakeAuthRepository(), hasSeenWelcome: false);

      expect(find.text('Get started'), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsNothing);
    });

    testWidgets('an account that has not been set up opens on onboarding', (
      WidgetTester tester,
    ) async {
      // Signing in is not the end of the flow. The account still has no
      // confirmed currency or time zone, and a bill saved before those are set
      // is a bill shown in the wrong money on the wrong day.
      await pumpApp(
        tester,
        FakeAuthRepository(initialUser: marc),
        onboarded: false,
      );

      expect(find.text('Money and time'), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
    });

    testWidgets('and a set-up account never sees either', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository(initialUser: marc));

      expect(find.text('Get started'), findsNothing);
      expect(find.text('Money and time'), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });
}
