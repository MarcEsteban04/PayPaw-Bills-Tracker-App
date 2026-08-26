import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paypaw/app/paypaw_app.dart';
import 'package:paypaw/app/router/app_routes.dart';
import 'package:paypaw/app/shell/app_destination.dart';
import 'package:paypaw/app/shell/paypaw_bottom_nav.dart';
import 'package:paypaw/core/providers/storage_providers.dart';
import 'package:paypaw/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the shell navigation.
///
/// Destinations are tapped by semantics label rather than by icon, which checks
/// two things at once: that the tap works, and that every destination is
/// reachable by a screen reader. An unlabelled icon button would pass an
/// icon-based test and fail a real user.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const PayPawApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the dashboard with the navigation visible', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(PayPawBottomNav), findsOneWidget);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('every destination is reachable and labelled', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    for (final AppDestination destination in AppDestination.values) {
      expect(
        find.bySemanticsLabel(destination.label),
        findsOneWidget,
        reason: '${destination.name} is missing an accessible label',
      );
    }
  });

  testWidgets('tapping a destination switches the visible screen', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.bySemanticsLabel(AppDestination.bills.label));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Bills'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(AppDestination.calendar.label));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Calendar'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(AppDestination.dashboard.label));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('only the selected destination shows its label', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    // The pill carries the label; inactive destinations are icon-only. This is
    // the visual contract of the reference navigation, so it is worth pinning.
    expect(
      find.descendant(
        of: find.byType(PayPawBottomNav),
        matching: find.text(AppDestination.dashboard.label),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(PayPawBottomNav),
        matching: find.text(AppDestination.bills.label),
      ),
      findsNothing,
    );
  });

  testWidgets('a route above the shell hides the navigation', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    // Pushed by route rather than tapped. The developer galleries lost their
    // entry on the settings screen — they are dev tools, reachable by URL — and
    // what this test is about is what a route above the shell does to the
    // navigation bar, not how anybody gets there.
    unawaited(
      GoRouter.of(tester.element(find.byType(PayPawBottomNav)))
          .pushNamed(AppRoutes.designSystem.routeName),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Design System'), findsOneWidget);
    expect(find.byType(PayPawBottomNav), findsNothing);
  });
}
