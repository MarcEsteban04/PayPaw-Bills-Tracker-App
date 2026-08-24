import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/app/paypaw_app.dart';
import 'package:paypaw/core/providers/storage_providers.dart';
import 'package:paypaw/core/providers/supabase_providers.dart';
import 'package:paypaw/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:paypaw/features/auth/domain/entities/authenticated_user.dart';
import 'package:paypaw/features/onboarding/presentation/controllers/onboarding_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_onboarding_progress.dart';
import '../../helpers/fake_auth_repository.dart';

/// A reset link that opens the app and then does nothing is the classic failure
/// of this flow, and it fails *silently* — no error, no crash, just a user
/// staring at the dashboard wondering what happened. So the navigation is tested
/// rather than assumed.
void main() {
  Future<void> pumpApp(
    WidgetTester tester,
    FakeAuthRepository repository,
  ) async {
    addTearDown(repository.dispose);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          isBackendConfiguredProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(repository),
          // A returning, set-up account. Otherwise the first-run gates take
          // priority over the dashboard these cases start from, and the test
          // would be describing onboarding rather than password recovery.
          onboardingProgressStoreProvider.overrideWithValue(
            FakeOnboardingProgress(onboarded: <String>{'user-1'}),
          ),
        ],
        child: const PayPawApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Signed in, because Sprint 15's guard sends an unauthenticated user to the
  // sign-in screen — so an unauthenticated fake would never start on the
  // dashboard.
  const AuthenticatedUser signedIn = AuthenticatedUser(
    id: 'user-1',
    email: 'marc@example.com',
    hasConfirmedEmail: true,
  );

  testWidgets('a reset link arriving on any screen is followed', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository(
      initialUser: signedIn,
    );
    await pumpApp(tester, repository);

    // The app starts on the dashboard; the link can arrive from anywhere.
    expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);

    repository.emitPasswordRecovery();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'New password'), findsOneWidget);
  });

  testWidgets('nothing happens without a reset link', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, FakeAuthRepository(initialUser: signedIn));

    expect(find.widgetWithText(AppBar, 'New password'), findsNothing);
    expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);
  });
}
