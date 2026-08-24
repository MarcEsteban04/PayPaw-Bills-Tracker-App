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

/// The add button beside the navigation bar.
///
/// It sits in the shell rather than on a screen, so recording a bill does not
/// start with finding the right tab first. These tests are about that: it is
/// present and it works from every destination.
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

  Finder addButton() => find.descendant(
    of: find.byType(PayPawBottomNav),
    matching: find.byIcon(Icons.add_rounded),
  );

  group('where it lives', () {
    testWidgets('beside the navigation bar, not inside it', (
      WidgetTester tester,
    ) async {
      // Not a fifth destination. Tapping it does not change which tab you are
      // on, and an action in a row of places is a navigation bar that lies about
      // what its items do.
      await pumpApp(tester);

      expect(addButton(), findsOneWidget);

      final Rect button = tester.getRect(addButton());
      final Rect profile = tester.getRect(
        find.bySemanticsLabel(AppDestination.profile.label),
      );

      // To the right of the last destination, which is Profile.
      expect(button.left, greaterThan(profile.right));
    });

    testWidgets('it is labelled for a screen reader', (
      WidgetTester tester,
    ) async {
      // The icon alone carries no word, so the semantics have to.
      await pumpApp(tester);

      expect(find.bySemanticsLabel('Add bill'), findsWidgets);
    });
  });

  group('what it does', () {
    testWidgets('opens the form', (WidgetTester tester) async {
      await pumpApp(tester);

      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Add bill'), findsOneWidget);
    });

    // One test per destination rather than a loop inside one. Re-pumping the app
    // in a loop left the pushed form in the tree, and the second iteration failed
    // looking for a navigation bar that was covered — a test failing for a reason
    // that has nothing to do with what it is checking.
    //
    // Four tests because "works on each screen" is the requirement, and checking
    // one and assuming the rest is how the Bills-only version passed review.
    for (final AppDestination destination in AppDestination.values) {
      testWidgets('from the ${destination.label} tab', (
        WidgetTester tester,
      ) async {
        await pumpApp(tester);

        await tester.tap(find.bySemanticsLabel(destination.label));
        await tester.pumpAndSettle();

        await tester.tap(addButton());
        await tester.pumpAndSettle();

        expect(find.widgetWithText(AppBar, 'Add bill'), findsOneWidget);
      });
    }

    testWidgets('and the form covers the navigation while it is open', (
      WidgetTester tester,
    ) async {
      // Pushed above the shell, so the bar — and this button — are not sitting
      // under a form.
      await pumpApp(tester);

      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(find.byType(PayPawBottomNav), findsNothing);
    });
  });

  group('on a small screen', () {
    testWidgets('it is still there, and nothing overflows', (
      WidgetTester tester,
    ) async {
      // The button takes a fixed cut of the row, which is what forced the bar to
      // give up its label earlier and tighten its padding. The action is the part
      // that must survive; the label is decoration.
      await pumpApp(tester, size: const Size(320, 640));

      expect(addButton(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
