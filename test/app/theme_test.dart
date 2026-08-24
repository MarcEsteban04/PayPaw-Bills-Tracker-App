import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/app/paypaw_app.dart';
import 'package:paypaw/app/shell/app_destination.dart';
import 'package:paypaw/app/shell/paypaw_bottom_nav.dart';
import 'package:paypaw/core/providers/storage_providers.dart';
import 'package:paypaw/core/theme/app_palette.dart';
import 'package:paypaw/core/theme/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dark mode, end to end.
///
/// The roadmap's last Phase 2 bullet is "verify all screens in both themes".
/// Doing that by eye is a chore that gets skipped, so it is a test: every
/// destination and both developer galleries are rendered in dark mode and
/// checked for layout errors, the same way the responsive suite checks sizes.
void main() {
  Future<SharedPreferences> pumpApp(
    WidgetTester tester, {
    Map<String, Object> stored = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const PayPawApp(),
      ),
    );
    await tester.pumpAndSettle();

    return preferences;
  }

  /// The palette actually in force, read from a widget deep in the tree.
  AppPalette paletteOf(WidgetTester tester) {
    return Theme.of(tester.element(find.byType(PayPawBottomNav)))
        .extension<AppPalette>()!;
  }

  /// Opens Profile and scrolls to the end of it.
  ///
  /// Scrolling all the way rather than using `scrollUntilVisible` on purpose:
  /// that stops as soon as the target enters the viewport, which can leave it
  /// underneath the floating navigation bar — and a tap then lands on the bar
  /// instead of the tile. At the end of the list the bottom padding keeps the
  /// tiles clear.
  Future<void> openProfileEnd(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel(AppDestination.profile.label));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
  }

  group('dark mode', () {
    testWidgets('a stored dark preference is applied at launch', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        stored: <String, Object>{ThemeModeController.storageKey: 'dark'},
      );

      // Compared by value rather than by identity: MaterialApp lerps themes, so
      // the palette in the tree is an interpolated instance, not the constant.
      expect(paletteOf(tester).surface, AppPalette.dark.surface);
      expect(paletteOf(tester).brightness, Brightness.dark);
    });

    testWidgets('every destination renders without a layout error', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        stored: <String, Object>{ThemeModeController.storageKey: 'dark'},
      );

      expect(tester.takeException(), isNull);

      for (final AppDestination destination in AppDestination.values) {
        await tester.tap(find.bySemanticsLabel(destination.label));
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: '${destination.name} broke in dark mode',
        );
      }
    });

    // A fresh app per gallery rather than navigating back between them: a pushed
    // route covers the shell, so there is no navigation bar to return with, and
    // this keeps each case independent anyway.
    for (final (String tile, String title) in <(String, String)>[
      ('Design system', 'Design System'),
      ('Components', 'Components'),
    ]) {
      testWidgets('the $tile gallery renders', (WidgetTester tester) async {
        await pumpApp(
          tester,
          stored: <String, Object>{ThemeModeController.storageKey: 'dark'},
        );
        await openProfileEnd(tester);

        // widgetWithText, not find.text: tapping the bare Text can land outside
        // the row's own gesture area, and "tap the row labelled X" is what this
        // test actually means.
        await tester.tap(find.widgetWithText(ListTile, tile));
        // Several explicit frames rather than pumpAndSettle: the components
        // gallery animates a spinner and skeletons forever, so settling never
        // happens. One big pump is not enough either — the push needs a frame to
        // insert the route before its transition can run.
        for (int frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Proves the tap navigated. Without this the test would also pass if the
        // tap missed and we never left Profile.
        expect(find.widgetWithText(AppBar, title), findsOneWidget);

        expect(
          tester.takeException(),
          isNull,
          reason: '$tile broke in dark mode',
        );
      });
    }
  });

  group('switching themes', () {
    testWidgets('from the Profile screen, and it sticks', (
      WidgetTester tester,
    ) async {
      final SharedPreferences preferences = await pumpApp(tester);

      // Nothing stored, so the app follows the device, which the test binding
      // reports as light.
      expect(paletteOf(tester).surface, AppPalette.light.surface);

      await openProfileEnd(tester);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(paletteOf(tester).surface, AppPalette.dark.surface);
      expect(preferences.getString(ThemeModeController.storageKey), 'dark');

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(paletteOf(tester).surface, AppPalette.light.surface);
      expect(preferences.getString(ThemeModeController.storageKey), 'light');
    });

    testWidgets('the canvas gradient follows the theme', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        stored: <String, Object>{ThemeModeController.storageKey: 'dark'},
      );

      // The gradient is painted once in PayPawApp's builder from
      // context.colors, which is the mechanism that makes it theme-aware. If it
      // ever regressed to a constant, this is what would catch it.
      expect(
        paletteOf(tester).canvas.colors.first,
        AppPalette.dark.canvasStart,
      );
    });
  });
}
