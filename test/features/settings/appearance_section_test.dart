import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/providers/storage_providers.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/core/theme/theme_mode_controller.dart';
import 'package:paypaw/features/settings/presentation/widgets/appearance_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light, dark, or follow the device.
///
/// The tiles are pictures, so what can be asserted is what they *say*: the three
/// options exist, the one in use is marked as chosen, a tap changes and
/// remembers it, and System — the only option whose name does not describe its
/// result — says what it will actually do.
void main() {
  late SharedPreferences preferences;

  Future<void> pumpSection(
    WidgetTester tester, {
    ThemeMode? stored,
    Brightness platform = Brightness.light,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      if (stored != null) ThemeModeController.storageKey: stored.name,
    });
    preferences = await SharedPreferences.getInstance();

    tester.platformDispatcher.platformBrightnessTestValue = platform;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(child: AppearanceSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The tile for one option, found by the label under it.
  Finder option(String label) => find.bySemanticsLabel(label);

  testWidgets('offers all three', (WidgetTester tester) async {
    await pumpSection(tester);

    expect(option('System'), findsOneWidget);
    expect(option('Light'), findsOneWidget);
    expect(option('Dark'), findsOneWidget);
  });

  testWidgets('marks the one in use, and only that one', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, stored: ThemeMode.dark);

    expect(
      tester.getSemantics(option('Dark')),
      isSemantics(isSelected: true, isButton: true, label: 'Dark'),
    );
    expect(
      tester.getSemantics(option('Light')),
      isSemantics(isSelected: false, isButton: true, label: 'Light'),
    );
  });

  testWidgets('a tap changes the theme and remembers it', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, stored: ThemeMode.system);

    await tester.tap(option('Dark'));
    await tester.pumpAndSettle();

    expect(preferences.getString(ThemeModeController.storageKey), 'dark');
    expect(
      tester.getSemantics(option('Dark')),
      isSemantics(isSelected: true, isButton: true, label: 'Dark'),
    );
  });

  group('the line under the tiles', () {
    testWidgets('says what System will actually do', (
      WidgetTester tester,
    ) async {
      // System is the only option whose name does not describe its result.
      await pumpSection(
        tester,
        stored: ThemeMode.system,
        platform: Brightness.dark,
      );

      expect(
        find.text('Following your phone, which is dark right now.'),
        findsOneWidget,
      );
    });

    testWidgets('and follows the device rather than guessing', (
      WidgetTester tester,
    ) async {
      await pumpSection(tester, stored: ThemeMode.system);

      expect(
        find.text('Following your phone, which is light right now.'),
        findsOneWidget,
      );
    });

    testWidgets('and says nothing when the choice speaks for itself', (
      WidgetTester tester,
    ) async {
      await pumpSection(tester, stored: ThemeMode.dark);

      expect(find.textContaining('Following your phone'), findsNothing);
    });
  });
}
