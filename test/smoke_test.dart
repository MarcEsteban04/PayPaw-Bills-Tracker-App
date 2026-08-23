import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/app/paypaw_app.dart';
import 'package:paypaw/core/providers/storage_providers.dart';
import 'package:paypaw/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boot test for the architecture and theme wiring.
///
/// It deliberately asserts nothing about which screen is showing: the initial
/// route changes as the app grows, and a test that has to be edited every time a
/// route moves is a test nobody trusts. What it does assert is the wiring that
/// must never break — providers resolved, a route matched, the design tokens
/// reaching `Theme.of(context)` — which is exactly the class of failure that is
/// otherwise only found by launching the app.
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

  testWidgets('app boots and renders its initial route', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('design tokens reach the widget tree', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final ThemeData theme = Theme.of(
      tester.element(find.byType(Scaffold).first),
    );

    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.scaffoldBackgroundColor, AppColors.canvasCream);
    // Cards and buttons are flat because PayPaw paints its own soft shadows.
    expect(theme.cardTheme.elevation, 0);
  });
}
