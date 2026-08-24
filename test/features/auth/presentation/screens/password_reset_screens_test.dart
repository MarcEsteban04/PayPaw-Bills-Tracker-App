import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/core/presentation/widgets/app_text_field.dart';
import 'package:paypaw/core/providers/supabase_providers.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:paypaw/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:paypaw/features/auth/presentation/screens/reset_password_screen.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeAuthRepository repository,
    Widget screen,
  ) async {
    addTearDown(repository.dispose);

    // A phone-shaped surface, not the 800x600 default. These screens are laid
    // out for a phone, and on the default surface the submit button sits below
    // the fold — a fact about the test viewport rather than the design.
    tester.view
      ..physicalSize = const Size(392 * 3, 830 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isBackendConfiguredProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('forgot password', () {
    testWidgets('an invalid address never reaches the backend', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository();
      await pumpScreen(tester, repository, const ForgotPasswordScreen());

      await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email address'), findsOneWidget);
      expect(repository.sendPasswordResetCalls, 0);
    });

    testWidgets('confirms without revealing whether the account exists', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository();
      await pumpScreen(tester, repository, const ForgotPasswordScreen());

      await tester.enterText(_field('Email'), 'marc@example.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
      await tester.pumpAndSettle();

      // "If that address has an account" is the privacy behaviour, not hedging:
      // an endpoint that confirms an address exists is a way to enumerate users.
      expect(
        find.textContaining('If marc@example.com has an account'),
        findsOneWidget,
      );
      expect(repository.sendPasswordResetCalls, 1);
    });

    testWidgets('shows a rate limit inline and keeps the form', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeAuthRepository(
          error: const ValidationException(
            message: 'Too many attempts. Wait a minute and try again.',
          ),
        ),
        const ForgotPasswordScreen(),
      );

      await tester.enterText(_field('Email'), 'marc@example.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
      await tester.pumpAndSettle();

      expect(
        find.text('Too many attempts. Wait a minute and try again.'),
        findsOneWidget,
      );
      expect(_field('Email'), findsOneWidget);
    });
  });

  group('reset password', () {
    testWidgets('applies the same rules as registration', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository();
      await pumpScreen(tester, repository, const ResetPasswordScreen());

      await tester.enterText(_field('New password'), 'short');
      await tester.tap(find.widgetWithText(FilledButton, 'Save new password'));
      await tester.pumpAndSettle();

      expect(find.textContaining('at least 8 characters'), findsOneWidget);
      expect(repository.updatePasswordCalls, 0);
    });

    testWidgets('catches a mismatched confirmation locally', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repository = FakeAuthRepository();
      await pumpScreen(tester, repository, const ResetPasswordScreen());

      await tester.enterText(_field('New password'), 'paypaw2027');
      await tester.enterText(_field('Confirm new password'), 'paypaw2028');
      await tester.tap(find.widgetWithText(FilledButton, 'Save new password'));
      await tester.pumpAndSettle();

      expect(find.text('Those passwords do not match'), findsOneWidget);
      expect(repository.updatePasswordCalls, 0);
    });

    testWidgets('shows the requirements checklist live', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeAuthRepository(),
        const ResetPasswordScreen(),
      );

      expect(
        find.byIcon(Icons.radio_button_unchecked_rounded),
        findsNWidgets(3),
      );

      await tester.enterText(_field('New password'), 'paypaw2027');
      await tester.pump();

      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
    });

    testWidgets('reports an expired link without losing the form', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeAuthRepository(
          error: const AuthenticationException(
            message:
                'That reset link has expired or was already used. Request a '
                'new one.',
          ),
        ),
        const ResetPasswordScreen(),
      );

      await tester.enterText(_field('New password'), 'paypaw2027');
      await tester.enterText(_field('Confirm new password'), 'paypaw2027');
      await tester.tap(find.widgetWithText(FilledButton, 'Save new password'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('has expired or was already used'),
        findsOneWidget,
      );
      expect(_field('New password'), findsOneWidget);
    });
  });
}

/// Finds a field by the label rendered above it.
Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(AppTextField)),
  matching: find.byType(TextFormField),
);
