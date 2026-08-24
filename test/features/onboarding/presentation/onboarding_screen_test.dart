import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paypaw/app/router/app_routes.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/auth/domain/entities/authenticated_user.dart';
import 'package:paypaw/features/auth/presentation/controllers/current_user_provider.dart';
import 'package:paypaw/features/onboarding/domain/entities/account_setup.dart';
import 'package:paypaw/features/onboarding/domain/repositories/account_setup_repository.dart';
import 'package:paypaw/features/onboarding/presentation/controllers/onboarding_providers.dart';
import 'package:paypaw/features/onboarding/presentation/screens/onboarding_screen.dart';

import '../../../helpers/fake_onboarding_progress.dart';

/// Records what was saved, and can be told to fail.
class _FakeRepository implements AccountSetupRepository {
  AccountSetup? saved;
  int calls = 0;
  AppException? failure;

  @override
  Future<void> save(AccountSetup setup) async {
    calls++;
    if (failure case final AppException exception) {
      throw exception;
    }
    saved = setup;
  }
}

void main() {
  const AuthenticatedUser marc = AuthenticatedUser(
    id: 'user-1',
    email: 'marc@example.com',
    hasConfirmedEmail: true,
  );

  late _FakeRepository repository;
  late FakeOnboardingProgress progress;

  setUp(() {
    repository = _FakeRepository();
    progress = FakeOnboardingProgress();
  });

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    AuthenticatedUser? user = marc,
    AccountSetup defaults = const AccountSetup(),
  }) async {
    tester.view
      ..physicalSize = const Size(392 * 3, 830 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountSetupRepositoryProvider.overrideWithValue(repository),
          onboardingProgressStoreProvider.overrideWithValue(progress),
          // Overridden rather than left to guess from the host machine, so the
          // suite does not pass in Manila and fail in CI.
          deviceSetupDefaultsProvider.overrideWithValue(defaults),
          currentUserProvider.overrideWith(
            (Ref ref) => Stream<AuthenticatedUser?>.value(user),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: GoRouter(
            initialLocation: AppRoutes.onboarding.path,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.onboarding.path,
                name: AppRoutes.onboarding.routeName,
                builder: (_, _) => const OnboardingScreen(),
              ),
              GoRoute(
                path: AppRoutes.dashboard.path,
                name: AppRoutes.dashboard.routeName,
                builder: (_, _) => const Scaffold(body: Text('dashboard stub')),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  group('the shape of the flow', () {
    testWidgets('starts on step one of two', (WidgetTester tester) async {
      await pumpOnboarding(tester);

      expect(find.text('Money and time'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 1 of 2'), findsOneWidget);
    });

    testWidgets('Continue advances, and the label becomes final', (
      WidgetTester tester,
    ) async {
      await pumpOnboarding(tester);

      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('When should we tell you?'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 2 of 2'), findsOneWidget);
      // "Continue" on a last step is a lie about what the button does.
      expect(find.text('Finish setup'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('back returns to step one without losing answers', (
      WidgetTester tester,
    ) async {
      await pumpOnboarding(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Money and time'), findsOneWidget);
    });

    testWidgets('there is no back arrow on the first step', (
      WidgetTester tester,
    ) async {
      // It would have to either do nothing or abandon setup. Skip is the honest
      // way out, and it is already in the bar.
      await pumpOnboarding(tester);

      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(find.text('Skip'), findsOneWidget);
    });
  });

  group('finishing', () {
    testWidgets('saves the answers and leaves', (WidgetTester tester) async {
      await pumpOnboarding(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();

      expect(repository.saved, isNotNull);
      expect(progress.onboarded, contains('user-1'));
      expect(find.text('dashboard stub'), findsOneWidget);
    });

    testWidgets('carries the device guesses through when nothing is changed', (
      WidgetTester tester,
    ) async {
      // The guess is the answer for most users, so it has to actually be saved
      // rather than shown and then dropped.
      await pumpOnboarding(
        tester,
        defaults: const AccountSetup(
          currency: 'USD',
          timeZone: 'America/New_York',
        ),
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();

      expect(repository.saved?.currency, 'USD');
      expect(repository.saved?.timeZone, 'America/New_York');
    });

    testWidgets('a reminder day can be turned off before saving', (
      WidgetTester tester,
    ) async {
      await pumpOnboarding(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The default is 3, 1 and 0.
      await tester.tap(find.text('On the day'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();

      expect(repository.saved?.reminderDaysBefore, <int>[3, 1]);
    });

    testWidgets('reminders can be turned off entirely', (
      WidgetTester tester,
    ) async {
      await pumpOnboarding(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();

      // A row saying "off", not an absent row: absent is indistinguishable from
      // never asked, and Phase 8 needs to tell those apart.
      expect(repository.saved?.remindersEnabled, isFalse);
      expect(repository.saved?.reminderDaysBefore, isNotEmpty);
    });
  });

  group('skipping', () {
    testWidgets('still writes the defaults', (WidgetTester tester) async {
      // So a skipped account and a completed-but-unchanged one are identical,
      // and no later feature has to handle a third case.
      await pumpOnboarding(tester);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(repository.saved, const AccountSetup());
      expect(progress.onboarded, contains('user-1'));
      expect(find.text('dashboard stub'), findsOneWidget);
    });

    testWidgets('is available on the last step too', (
      WidgetTester tester,
    ) async {
      await pumpOnboarding(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('ignores anything already chosen', (WidgetTester tester) async {
      // Skip means "use the defaults", not "save whatever I half-filled in".
      await pumpOnboarding(
        tester,
        defaults: const AccountSetup(currency: 'JPY'),
      );

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(repository.saved?.currency, AccountSetup.defaultCurrency);
    });
  });

  group('when the save fails', () {
    testWidgets('the message is shown and the screen stays put', (
      WidgetTester tester,
    ) async {
      repository.failure = const NetworkException();

      await pumpOnboarding(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No internet connection'), findsOneWidget);
      expect(find.text('dashboard stub'), findsNothing);
    });

    testWidgets('onboarding is not marked done', (WidgetTester tester) async {
      // Marking it before the write succeeded would cost the user the whole step
      // with no way back to it — the guard would never send them here again.
      repository.failure = const NetworkException();

      await pumpOnboarding(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();

      expect(progress.onboarded, isEmpty);
    });

    testWidgets('it can be retried', (WidgetTester tester) async {
      repository.failure = const NetworkException();

      await pumpOnboarding(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();

      repository.failure = null;

      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
      expect(find.text('dashboard stub'), findsOneWidget);
    });
  });

  group('without a session', () {
    testWidgets('it says so rather than failing at the database', (
      WidgetTester tester,
    ) async {
      // Reachable if the session ends mid-form. Every write here is checked
      // against auth.uid(), so sending it would only produce an error about
      // policies.
      await pumpOnboarding(tester, user: null);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(repository.calls, 0);
      expect(find.textContaining('session ended'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('neither step overflows at 2x text on a small phone', (
      WidgetTester tester,
    ) async {
      tester.view
        ..physicalSize = const Size(320 * 3, 568 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSetupRepositoryProvider.overrideWithValue(repository),
            onboardingProgressStoreProvider.overrideWithValue(progress),
            deviceSetupDefaultsProvider.overrideWithValue(const AccountSetup()),
            currentUserProvider.overrideWith(
              (Ref ref) => Stream<AuthenticatedUser?>.value(marc),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // The footer button is outside the scroll view, so it has to still be
      // there at 2x — a wizard whose Continue button scrolls away is a wizard
      // people get stuck in.
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Finish setup'), findsOneWidget);
    });
  });
}
