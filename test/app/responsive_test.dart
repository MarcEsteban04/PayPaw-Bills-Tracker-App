import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paypaw/app/paypaw_app.dart';
import 'package:paypaw/app/router/app_routes.dart';
import 'package:paypaw/app/shell/app_destination.dart';
import 'package:paypaw/app/shell/paypaw_bottom_nav.dart';
import 'package:paypaw/core/presentation/layout/app_breakpoints.dart';
import 'package:paypaw/core/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One window to render the app in.
class _Window {
  const _Window(this.name, this.size);

  final String name;
  final Size size;

  @override
  String toString() => '$name (${size.width.toInt()}x${size.height.toInt()})';
}

/// Screen sizes worth caring about on Android, from the smallest still-shipping
/// phone up to a landscape tablet.
const List<_Window> _windows = <_Window>[
  _Window('small phone', Size(320, 640)),
  _Window('common phone', Size(360, 800)),
  _Window('large phone', Size(412, 915)),
  _Window('small tablet', Size(600, 960)),
  _Window('landscape tablet', Size(1024, 768)),
];

/// System font sizes: default, Android's largest, and beyond it to prove the
/// clamp holds.
const List<double> _textScales = <double>[1, 1.6, 2];

/// Layout regression tests.
///
/// Overflow is the failure mode that hides best: it does not crash, it does not
/// fail a unit test, and on the developer's own phone it often does not appear at
/// all. So rather than eyeball screens, this walks every destination in every
/// window at every font size and fails if Flutter reports a single layout error.
///
/// `tester.takeException()` is what does the work — a `RenderFlex overflowed`
/// error surfaces there, and would otherwise only ever be a yellow stripe in a
/// screenshot nobody took.
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

  void useWindow(WidgetTester tester, Size size, double textScale) {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;

    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  group('no overflow anywhere', () {
    for (final _Window window in _windows) {
      for (final double textScale in _textScales) {
        testWidgets('$window at text scale $textScale', (
          WidgetTester tester,
        ) async {
          useWindow(tester, window.size, textScale);
          await pumpApp(tester);

          expect(
            tester.takeException(),
            isNull,
            reason: 'the dashboard overflowed in $window at $textScale',
          );

          for (final AppDestination destination in AppDestination.values) {
            await tester.tap(find.bySemanticsLabel(destination.label));
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: '${destination.name} overflowed in $window at $textScale',
            );
          }
        });
      }
    }
  });

  group('the developer galleries survive the smallest window', () {
    // These two are the densest screens in the app, so they are the most likely
    // to overflow — and they are also where a regression would be spotted last,
    // since nobody ships them.
    for (final (String gallery, AppRoutes route) in <(String, AppRoutes)>[
      ('Design system', AppRoutes.designSystem),
      ('Components', AppRoutes.components),
    ]) {
      testWidgets('$gallery at 320dp and text scale 2', (
        WidgetTester tester,
      ) async {
        useWindow(tester, const Size(320, 640), 2);
        await pumpApp(tester);

        // Pushed by route. These lost their entry on the settings screen when
        // the developer section went — they are dev tools reachable by URL now —
        // and what this test is about is whether they fit, not how to reach them.
        unawaited(
          GoRouter.of(tester.element(find.byType(PayPawBottomNav)))
              .pushNamed(route.routeName),
        );
        // Explicit pumps rather than pumpAndSettle: the components gallery
        // contains a spinner and pulsing skeletons, and a tree with a repeating
        // animation never goes quiet, so pumpAndSettle would time out instead of
        // reporting anything useful.
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);

        // Walk the whole list. An overflow further down would otherwise never be
        // laid out, and so never be caught.
        // .last, not just byType: the settings screen behind this pushed route
        // has a ListView of its own, and the gallery is the one on top.
        final Finder galleryList = find.byType(ListView).last;

        for (int screenful = 0; screenful < 15; screenful++) {
          // warnIfMissed: false — once the list is scrolled to its end the
          // drag origin can land on padding rather than a child, which is
          // harmless here.
          await tester.drag(
            galleryList,
            const Offset(0, -400),
            warnIfMissed: false,
          );
          await tester.pump(const Duration(milliseconds: 100));

          expect(
            tester.takeException(),
            isNull,
            reason: '$gallery overflowed $screenful screenful(s) down',
          );
        }
      });
    }
  });

  group('text scaling', () {
    testWidgets('is clamped to the app maximum', (WidgetTester tester) async {
      useWindow(tester, const Size(360, 800), 3);
      await pumpApp(tester);

      final double effective = MediaQuery.textScalerOf(
        tester.element(find.byType(PayPawBottomNav)),
      ).scale(1);

      expect(effective, PayPawApp.maxTextScale);
    });

    testWidgets('is clamped to the app minimum', (WidgetTester tester) async {
      useWindow(tester, const Size(360, 800), 0.5);
      await pumpApp(tester);

      final double effective = MediaQuery.textScalerOf(
        tester.element(find.byType(PayPawBottomNav)),
      ).scale(1);

      expect(effective, PayPawApp.minTextScale);
    });
  });

  group('bottom navigation labels', () {
    testWidgets('are shown when there is room', (WidgetTester tester) async {
      useWindow(tester, const Size(412, 915), 1);
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byType(PayPawBottomNav),
          matching: find.text(AppDestination.dashboard.label),
        ),
        findsOneWidget,
      );
    });

    testWidgets('are dropped when the pill would not fit', (
      WidgetTester tester,
    ) async {
      // A narrow screen at the largest font size: the label is given up rather
      // than clipped mid-word.
      useWindow(tester, const Size(320, 640), 2);
      await pumpApp(tester);

      expect(
        find.descendant(
          of: find.byType(PayPawBottomNav),
          matching: find.text(AppDestination.dashboard.label),
        ),
        findsNothing,
      );

      // Still reachable, still labelled for a screen reader.
      expect(
        find.bySemanticsLabel(AppDestination.dashboard.label),
        findsOneWidget,
      );
    });
  });

  group('reduced motion', () {
    testWidgets('the navigation pill snaps instead of growing', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      useWindow(tester, const Size(412, 915), 1);
      await pumpApp(tester);

      // Scoped to the bar: once Bills is open its app bar carries the same
      // label, and an unscoped finder would match both.
      final Finder bills = find.descendant(
        of: find.byType(PayPawBottomNav),
        matching: find.bySemanticsLabel(AppDestination.bills.label),
      );
      await tester.tap(bills);

      // One frame only. With animations on, the pill would still be mid-grow.
      await tester.pump();
      final Size immediate = tester.getSize(bills);

      await tester.pumpAndSettle();
      final Size settled = tester.getSize(bills);

      expect(immediate.width, settled.width);
    });
  });

  group('wide windows', () {
    testWidgets('cap the content width instead of stretching', (
      WidgetTester tester,
    ) async {
      useWindow(tester, const Size(1024, 768), 1);
      await pumpApp(tester);

      final Size navSize = tester.getSize(find.byType(PayPawBottomNav));

      expect(navSize.width, lessThanOrEqualTo(AppBreakpoints.maxNavWidth));
    });

    testWidgets('do not turn the navigation bar into a full-screen box', (
      WidgetTester tester,
    ) async {
      useWindow(tester, const Size(412, 915), 1);
      await pumpApp(tester);

      final Rect nav = tester.getRect(find.byType(PayPawBottomNav));

      // Regression test. Wrapping the bottom slot in a height-filling Align
      // expanded it to the whole screen and pinned the bar to the top of that
      // box, so the bar rendered at the top of the display and an invisible
      // full-screen box ate every tap. The width assertions below did not catch
      // it, because the width was correct the whole time.
      expect(nav.bottom, closeTo(915, 1));
      expect(nav.height, lessThan(120));
    });

    testWidgets('leave a phone-width window alone', (
      WidgetTester tester,
    ) async {
      useWindow(tester, const Size(412, 915), 1);
      await pumpApp(tester);

      // Below the cap the constraint is invisible: the bar still spans the
      // screen, as the reference design shows it.
      expect(tester.getSize(find.byType(PayPawBottomNav)).width, 412);
    });
  });
}
