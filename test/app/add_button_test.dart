import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/app/paypaw_app.dart';
import 'package:paypaw/app/shell/app_destination.dart';
import 'package:paypaw/app/shell/paypaw_bottom_nav.dart';
import 'package:paypaw/core/providers/storage_providers.dart';
import 'package:paypaw/core/providers/supabase_providers.dart';
import 'package:paypaw/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:paypaw/features/auth/domain/entities/authenticated_user.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_repository_provider.dart';
import 'package:paypaw/features/onboarding/presentation/controllers/onboarding_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/helpers/fake_auth_repository.dart';
import '../features/bills/helpers/fake_bill_repository.dart';
import '../helpers/fake_onboarding_progress.dart';

/// The add button, in the Bills header.
///
/// It used to float beside the navigation bar, where it worked from every tab.
/// It sits over the list it adds to now, and the bar is navigation only. These
/// tests are about that move: where it is, that it works, and that the other
/// route to the form did not disappear with it.
void main() {
  const AuthenticatedUser marc = AuthenticatedUser(
    id: 'user-1',
    email: 'marc@example.com',
    hasConfirmedEmail: true,
  );

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(412, 915),
  }) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final FakeAuthRepository auth = FakeAuthRepository(initialUser: marc);
    addTearDown(auth.dispose);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          isBackendConfiguredProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(auth),
          billRepositoryProvider.overrideWithValue(FakeBillRepository()),
          onboardingProgressStoreProvider.overrideWithValue(
            FakeOnboardingProgress(onboarded: <String>{marc.id}),
          ),
        ],
        child: const PayPawApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The add button, wherever it is. Scoped to the app bar so it cannot match
  /// the dashboard's "Add bill" shortcut, which uses the same icon.
  Finder addButton() => find.descendant(
    of: find.byType(AppBar),
    matching: find.byIcon(Icons.add_rounded),
  );

  group('where it lives', () {
    testWidgets('in the Bills header, over the list it adds to', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.bySemanticsLabel(AppDestination.bills.label));
      await tester.pumpAndSettle();

      expect(addButton(), findsOneWidget);
    });

    testWidgets('and no longer on the navigation bar', (
      WidgetTester tester,
    ) async {
      // It floated beside the pill so it worked from every tab. The bar is
      // navigation now and says only where you can go.
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byType(PayPawBottomNav),
          matching: find.byIcon(Icons.add_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('it is labelled for a screen reader', (
      WidgetTester tester,
    ) async {
      // The icon alone carries no word, so the semantics have to.
      await pumpApp(tester);
      await tester.tap(find.bySemanticsLabel(AppDestination.bills.label));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Add bill'), findsWidgets);
    });
  });

  group('what it does', () {
    testWidgets('opens the form', (WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.bySemanticsLabel(AppDestination.bills.label));
      await tester.pumpAndSettle();

      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Add bill'), findsOneWidget);
    });

    testWidgets('and the form covers the navigation while it is open', (
      WidgetTester tester,
    ) async {
      // Pushed above the shell, so the bar is not sitting under a form.
      await pumpApp(tester);
      await tester.tap(find.bySemanticsLabel(AppDestination.bills.label));
      await tester.pumpAndSettle();

      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(find.byType(PayPawBottomNav), findsNothing);
    });
  });

  group('the other way in', () {
    testWidgets('the dashboard still offers Add bill', (
      WidgetTester tester,
    ) async {
      // Moving the button off the bar cost three tabs their route to the form.
      // This is the one that matters: the dashboard is where the app opens, and
      // its shortcut row is what keeps adding a bill from starting with "find
      // the right tab first".
      await pumpApp(tester);

      expect(find.text('Add bill'), findsWidgets);
    });
  });

  group('on a small screen', () {
    testWidgets('it is still there, and nothing overflows', (
      WidgetTester tester,
    ) async {
      // Three controls now share the Bills app bar, and one of them widens with
      // the filter count.
      await pumpApp(tester, size: const Size(320, 640));
      await tester.tap(find.bySemanticsLabel(AppDestination.bills.label));
      await tester.pumpAndSettle();

      expect(addButton(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
