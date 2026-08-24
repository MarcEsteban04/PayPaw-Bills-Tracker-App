import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/app/paypaw_app.dart';
import 'package:paypaw/core/providers/storage_providers.dart';
import 'package:paypaw/core/providers/supabase_providers.dart';
import 'package:paypaw/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:paypaw/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:paypaw/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:paypaw/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:paypaw/features/onboarding/presentation/controllers/onboarding_providers.dart';
import 'package:paypaw/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_onboarding_progress.dart';
import '../../helpers/fake_auth_repository.dart';

/// Getting between the auth screens.
///
/// Written because of a dead end a user hit: tapping "Get started" on the welcome
/// screen landed on sign-up with **no back button and no link to sign-in**.
/// Someone who already had an account was stuck there. The cause was `go`
/// replacing the navigation stack, so there was nothing to pop and Flutter drew
/// no back affordance — nothing looked broken, and every screen tested fine on
/// its own.
///
/// These tests drive the real router, because that is the only place the bug
/// existed.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(392 * 3, 830 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final FakeAuthRepository repository = FakeAuthRepository();
    addTearDown(repository.dispose);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          isBackendConfiguredProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(repository),
          // A fresh install, so the app opens where a real one does.
          onboardingProgressStoreProvider.overrideWithValue(
            FakeOnboardingProgress(hasSeenWelcome: false),
          ),
        ],
        child: const PayPawApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapBack(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
  }

  group('from the welcome screen', () {
    testWidgets('Get started reaches sign-up, which can reach sign-in', (
      WidgetTester tester,
    ) async {
      // The exact dead end. Both ways out are checked, because either one alone
      // would have been enough to avoid it and neither existed.
      await pumpApp(tester);
      expect(find.byType(WelcomeScreen), findsOneWidget);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.byType(SignUpScreen), findsOneWidget);

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('and sign-up has a back button that works', (
      WidgetTester tester,
    ) async {
      // `go` left nothing to pop, so Flutter drew no back button at all. The
      // scaffold now falls back to a named route, which is why one is here.
      await pumpApp(tester);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      await tapBack(tester);

      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('the sign-in link goes straight to sign-in', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });

  group('between sign-in and its neighbours', () {
    testWidgets('sign-in reaches sign-up and comes back', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create one'));
      await tester.pumpAndSettle();
      expect(find.byType(SignUpScreen), findsOneWidget);

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('sign-in reaches forgot-password and comes back', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot your password?'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);

      // Pushed rather than replaced, so back really does pop here.
      await tapBack(tester);

      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('forgot-password also has an explicit way back', (
      WidgetTester tester,
    ) async {
      // For the case where it was opened by a deep link and there is no stack.
      await pumpApp(tester);
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot your password?'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back to sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });

  group('every auth screen', () {
    testWidgets('has a back affordance and a cross-link', (
      WidgetTester tester,
    ) async {
      // The rule the shared scaffold exists to enforce: no auth screen is a dead
      // end. Previously sign-up had neither.
      await pumpApp(tester);

      for (final String entry in <String>[
        'Get started',
        'I already have an account',
      ]) {
        await pumpApp(tester);
        await tester.tap(find.text(entry));
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.arrow_back_rounded),
          findsOneWidget,
          reason: 'no back button after tapping "$entry"',
        );
      }
    });
  });
}
