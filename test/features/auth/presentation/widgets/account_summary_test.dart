import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/providers/supabase_providers.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:paypaw/features/auth/domain/entities/authenticated_user.dart';
import 'package:paypaw/features/auth/presentation/widgets/account_summary.dart';

import '../../helpers/fake_auth_repository.dart';

/// Three states, and the third is the one worth having a test for: an app with
/// no backend configuration is not "signed out", it is unable to sign in, and
/// offering a button that can only fail is worse than saying so.
void main() {
  const AuthenticatedUser confirmed = AuthenticatedUser(
    id: 'user-1',
    email: 'marc@example.com',
    hasConfirmedEmail: true,
  );

  Future<void> pumpSummary(
    WidgetTester tester, {
    required FakeAuthRepository repository,
    bool configured = true,
  }) async {
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isBackendConfiguredProvider.overrideWithValue(configured),
          authRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(child: AccountSummary()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('says so when there is no backend', (WidgetTester tester) async {
    await pumpSummary(
      tester,
      repository: FakeAuthRepository(initialUser: confirmed),
      configured: false,
    );

    expect(find.textContaining('No backend configured'), findsOneWidget);
    // No button that could only fail.
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);
  });

  testWidgets('offers both ways in when signed out', (
    WidgetTester tester,
  ) async {
    await pumpSummary(tester, repository: FakeAuthRepository());

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Create account'),
      findsOneWidget,
    );
  });

  testWidgets('shows the signed-in address', (WidgetTester tester) async {
    await pumpSummary(
      tester,
      repository: FakeAuthRepository(initialUser: confirmed),
    );

    expect(find.text('marc@example.com'), findsOneWidget);
    expect(find.text('Signed in'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);
  });

  testWidgets('flags an unconfirmed address', (WidgetTester tester) async {
    await pumpSummary(
      tester,
      repository: FakeAuthRepository(
        initialUser: const AuthenticatedUser(
          id: 'user-2',
          email: 'new@example.com',
          hasConfirmedEmail: false,
        ),
      ),
    );

    // Signed in but not confirmed is a real state, and the user needs to know
    // why some things may not work.
    expect(find.text('Email not confirmed'), findsOneWidget);
  });

  testWidgets('follows a session ending while the screen is open', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository(
      initialUser: confirmed,
    );
    await pumpSummary(tester, repository: repository);
    expect(find.text('marc@example.com'), findsOneWidget);

    repository.emitSession(null);
    await tester.pumpAndSettle();

    expect(find.text('marc@example.com'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
