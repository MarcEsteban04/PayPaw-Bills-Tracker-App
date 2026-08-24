import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/core/presentation/widgets/app_text_field.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:paypaw/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:paypaw/features/auth/presentation/screens/sign_up_screen.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeAuthRepository repository,
  ) async {
    // A phone-shaped surface, not the 800x600 default. These screens are laid
    // out for a phone, and on the default surface the submit button sits below
    // the fold — a fact about the test viewport rather than the design.
    tester.view
      ..physicalSize = const Size(392 * 3, 830 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(theme: AppTheme.light, home: const SignUpScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(_field('Email'), 'marc@example.com');
    await tester.enterText(_field('Password'), 'paypaw2026');
    await tester.enterText(_field('Confirm password'), 'paypaw2026');
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
  }

  group('validation', () {
    testWidgets('an empty form never reaches the backend', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository();
      await pumpScreen(tester, repository);

      await submit(tester);

      expect(find.text('Enter your email address'), findsOneWidget);
      expect(find.text('Choose a password'), findsOneWidget);
      // The whole point of client-side validation: no wasted round trip.
      expect(repository.signUpCalls, 0);
    });

    testWidgets('a mismatched confirmation is caught locally', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository();
      await pumpScreen(tester, repository);

      await tester.enterText(_field('Email'), 'marc@example.com');
      await tester.enterText(_field('Password'), 'paypaw2026');
      await tester.enterText(_field('Confirm password'), 'paypaw2027');
      await submit(tester);

      expect(find.text('Those passwords do not match'), findsOneWidget);
      expect(repository.signUpCalls, 0);
    });

    testWidgets('the requirements checklist follows what is typed', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, FakeAuthRepository());

      // Nothing met yet: three empty circles.
      expect(
        find.byIcon(Icons.radio_button_unchecked_rounded),
        findsNWidgets(3),
      );

      await tester.enterText(_field('Password'), 'paypaw2026');
      await tester.pump();

      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
    });
  });

  group('submitting', () {
    testWidgets('sends what was typed', (WidgetTester tester) async {
      final FakeAuthRepository repository = FakeAuthRepository();
      await pumpScreen(tester, repository);

      await fillValidForm(tester);
      await submit(tester);

      expect(repository.signUpCalls, 1);
      expect(repository.lastEmail, 'marc@example.com');
      expect(repository.lastPassword, 'paypaw2026');
    });

    testWidgets('replaces the form with a confirmation, not a dashboard', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeAuthRepository(
          outcome: const SignUpNeedsConfirmation(email: 'marc@example.com'),
        ),
      );

      await fillValidForm(tester);
      await submit(tester);

      // With confirmation on, the account exists but nobody is signed in.
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining('marc@example.com'), findsOneWidget);
      expect(_field('Email'), findsNothing);
    });

    testWidgets('shows a backend rejection inline, keeping the form', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeAuthRepository(
          error: const ValidationException(
            message: 'That email is already registered.',
          ),
        ),
      );

      await fillValidForm(tester);
      await submit(tester);

      expect(find.text('That email is already registered.'), findsOneWidget);
      // The form stays, because the user needs to see what they typed to fix it.
      expect(_field('Email'), findsOneWidget);
    });

    testWidgets('never shows a raw error to the user', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeAuthRepository(error: StateError('index out of range at line 42')),
      );

      await fillValidForm(tester);
      await submit(tester);

      expect(find.textContaining('index out of range'), findsNothing);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('shows a spinner while it is working', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeAuthRepository(delay: const Duration(milliseconds: 300)),
      );

      await fillValidForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Check your email'), findsOneWidget);
    });
  });

  group('password visibility', () {
    testWidgets('starts hidden and can be revealed', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, FakeAuthRepository());

      expect(find.byTooltip('Show password'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Show password').first);
      await tester.pump();

      expect(find.byTooltip('Hide password'), findsOneWidget);
    });
  });
}

/// Finds a field by the label rendered above it.
///
/// `AppTextField` puts its label in a sibling `Text`, not in the field's own
/// decoration, so `widgetWithText` does not match. Scoping to the enclosing
/// `AppTextField` is what pins it down: the label is inside that widget, and
/// each one contains exactly one field.
Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(AppTextField)),
  matching: find.byType(TextFormField),
);
