import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/core/presentation/widgets/app_text_field.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:paypaw/features/auth/domain/entities/authenticated_user.dart';
import 'package:paypaw/features/auth/presentation/screens/sign_in_screen.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  /// Hosts the screen behind a route, so a successful sign-in has somewhere to
  /// pop back to — which is the behaviour under test, not an incidental detail.
  Future<void> pumpPushed(
    WidgetTester tester,
    FakeAuthRepository repository,
  ) async {
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
                ),
                child: const Text('open sign in'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open sign in'));
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(WidgetTester tester) async {
    await tester.enterText(_field('Email'), 'marc@example.com');
    await tester.enterText(_field('Password'), 'paypaw2026');
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }

  group('validation', () {
    testWidgets('an empty form never reaches the backend', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository();
      await pumpPushed(tester, repository);

      await submit(tester);

      expect(find.text('Enter your email address'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(repository.signInCalls, 0);
    });

    testWidgets('checks the password is present, not that it is strong', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository();
      await pumpPushed(tester, repository);

      // An account created under older rules must still be able to get in, and
      // "needs a number" is misleading when the password is simply mistyped.
      await tester.enterText(_field('Email'), 'marc@example.com');
      await tester.enterText(_field('Password'), 'old');
      await submit(tester);

      expect(find.textContaining('at least'), findsNothing);
      expect(repository.signInCalls, 1);
    });
  });

  group('signing in', () {
    testWidgets('sends what was typed', (WidgetTester tester) async {
      final FakeAuthRepository repository = FakeAuthRepository();
      await pumpPushed(tester, repository);

      await fillForm(tester);
      await submit(tester);

      expect(repository.lastEmail, 'marc@example.com');
      expect(repository.lastPassword, 'paypaw2026');
    });

    testWidgets('leaves the screen and says who signed in', (
      WidgetTester tester,
    ) async {
      await pumpPushed(
        tester,
        FakeAuthRepository(
          // Deliberately not the fake's default: this proves the address in the
          // message came from the repository rather than coinciding with it.
          signedInUser: const AuthenticatedUser(
            id: 'user-77',
            email: 'returning@example.com',
            hasConfirmedEmail: true,
          ),
        ),
      );

      await fillForm(tester);
      await submit(tester);

      expect(find.text('Signed in as returning@example.com'), findsOneWidget);
      // Back where they came from.
      expect(find.text('open sign in'), findsOneWidget);
    });

    testWidgets('shows a rejection inline and keeps the form', (
      WidgetTester tester,
    ) async {
      await pumpPushed(
        tester,
        FakeAuthRepository(
          error: const AuthenticationException(
            message: 'That email and password do not match an account.',
          ),
        ),
      );

      await fillForm(tester);
      await submit(tester);

      expect(
        find.text('That email and password do not match an account.'),
        findsOneWidget,
      );
      expect(_field('Email'), findsOneWidget);
    });

    testWidgets('never shows a raw error', (WidgetTester tester) async {
      await pumpPushed(
        tester,
        FakeAuthRepository(error: StateError('token parse failed at offset 7')),
      );

      await fillForm(tester);
      await submit(tester);

      expect(find.textContaining('offset 7'), findsNothing);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('shows a spinner while it is working', (
      WidgetTester tester,
    ) async {
      await pumpPushed(
        tester,
        FakeAuthRepository(delay: const Duration(milliseconds: 300)),
      );

      await fillForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });
}

/// Finds a field by the label rendered above it.
Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(AppTextField)),
  matching: find.byType(TextFormField),
);
