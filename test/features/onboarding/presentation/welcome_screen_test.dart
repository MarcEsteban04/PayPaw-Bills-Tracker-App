import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paypaw/app/router/app_routes.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/onboarding/presentation/controllers/onboarding_providers.dart';
import 'package:paypaw/features/onboarding/presentation/screens/welcome_screen.dart';

import '../../../helpers/fake_onboarding_progress.dart';

void main() {
  late FakeOnboardingProgress progress;

  // hasSeenWelcome: false, because this is the screen shown on a first install.
  setUp(() => progress = FakeOnboardingProgress(hasSeenWelcome: false));

  /// Pumps the screen at a chosen size and text scale.
  ///
  /// The screen is its own `Scaffold` and paints its own background, so it goes
  /// in as `home` rather than through the shared `pumpInApp` helper, which wraps
  /// its child in a second Scaffold and a Center.
  Future<void> pumpWelcome(
    WidgetTester tester, {
    Size size = const Size(392, 830),
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingProgressStoreProvider.overrideWithValue(progress),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: _testRouter(),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );

    await tester.pump();
  }

  group('what it shows', () {
    testWidgets('the pitch and both ways forward', (WidgetTester tester) async {
      await pumpWelcome(tester);

      expect(find.text('PayPaw'), findsOneWidget);
      expect(find.textContaining('Stay ahead of'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
    });

    testWidgets('a signed-out user is never asked to sign in twice', (
      WidgetTester tester,
    ) async {
      // Two paths, exactly: create an account, or say you have one. A welcome
      // screen with a third option is a menu, and a menu is not a welcome.
      await pumpWelcome(tester);

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });
  });

  group('leaving', () {
    testWidgets('Get started records that the screen was seen', (
      WidgetTester tester,
    ) async {
      await pumpWelcome(tester);

      expect(progress.hasSeenWelcome, isFalse);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      // Otherwise the guard sends the user straight back here, and sign-up is
      // unreachable — the screen would be a loop rather than a door.
      expect(progress.hasSeenWelcome, isTrue);
      expect(find.text('sign-up stub'), findsOneWidget);
    });

    testWidgets('so does the sign-in link', (WidgetTester tester) async {
      await pumpWelcome(tester);

      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();

      expect(progress.hasSeenWelcome, isTrue);
      expect(find.text('sign-in stub'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('does not overflow on a small phone', (
      WidgetTester tester,
    ) async {
      // 320×568 is the smallest screen Sprint 9 committed to supporting.
      await pumpWelcome(tester, size: const Size(320, 568));

      expect(tester.takeException(), isNull);
    });

    testWidgets('both actions land inside the viewport at normal text', (
      WidgetTester tester,
    ) async {
      // The check that sets the content reserve, and the one that caught it
      // being too small: at 380 the sign-in link sat twelve points below the
      // fold on an ordinary phone. Nothing looked broken — the primary button
      // was visible and the screen scrolled — so only measuring finds it.
      for (final Size size in <Size>[
        Size(320, 568), // smallest supported
        Size(392, 830), // common Android phone
        Size(412, 915), // large phone
      ]) {
        await pumpWelcome(tester, size: size);

        for (final String label in <String>[
          'Get started',
          'I already have an account',
        ]) {
          final Rect box = tester.getRect(find.text(label));

          expect(
            box.bottom,
            lessThanOrEqualTo(size.height),
            reason:
                '"$label" is below the fold at ${size.width}x${size.height}',
          );
        }
      }
    });

    testWidgets('does not overflow at 2x text', (WidgetTester tester) async {
      // The headline and both buttons grow; the artwork gives up its share and
      // the rest scrolls. An overflow here would clip the only two controls on
      // the screen.
      await pumpWelcome(tester, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('the actions stay reachable at 2x text on a small phone', (
      WidgetTester tester,
    ) async {
      // The worst case: least room, largest text. The buttons may be below the
      // fold, but they must exist and be scrollable to.
      await pumpWelcome(tester, size: const Size(320, 568), textScale: 2);

      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(find.text('Get started'), 200);

      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('the artwork gives up room when text is scaled up', (
      WidgetTester tester,
    ) async {
      // Tall enough that the art survives both scales, so the comparison is
      // between two real heights rather than against nothing.
      const Size size = Size(400, 1000);

      await pumpWelcome(tester, size: size);
      final double normalArt = tester.getSize(find.byType(Image)).height;

      await pumpWelcome(tester, size: size, textScale: 1.4);
      final double scaledArt = tester.getSize(find.byType(Image)).height;

      expect(
        scaledArt,
        lessThan(normalArt),
        reason: 'the headline needs the room more than the mascot does',
      );
    });

    testWidgets('and disappears entirely when there is no room at all', (
      WidgetTester tester,
    ) async {
      // Documented behaviour, not an accident: at large text on a small screen
      // the decoration goes and the words stay. Also the case that made
      // assert on a cacheHeight of zero, which is why it is dropped rather than
      // sized to nothing.
      await pumpWelcome(tester, size: const Size(320, 568), textScale: 2);

      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the dark commitment', () {
    testWidgets('is black whichever theme is active', (
      WidgetTester tester,
    ) async {
      // The illustration is drawn on black. A light scaffold behind it would
      // show a hard rectangle around the letterboxed image, which is exactly
      // what committing to dark avoids.
      for (final ThemeData theme in <ThemeData>[
        AppTheme.light,
        AppTheme.dark,
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingProgressStoreProvider.overrideWithValue(progress),
            ],
            child: MaterialApp(theme: theme, home: const WelcomeScreen()),
          ),
        );
        await tester.pump();

        final Scaffold scaffold = tester.widget<Scaffold>(
          find.byType(Scaffold),
        );

        expect(scaffold.backgroundColor, const Color(0xFF000000));
      }
    });
  });
}

/// A router with the welcome screen and stubs for the two places it can go.
///
/// The real `routerProvider` would drag in the auth guard, the session stream
/// and every screen in the app. What matters here is only that `goNamed` finds a
/// router and lands on the right route — so the destinations are labels.
GoRouter _testRouter() => GoRouter(
  initialLocation: AppRoutes.welcome.path,
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.welcome.path,
      name: AppRoutes.welcome.routeName,
      builder: (_, _) => const WelcomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.signUp.path,
      name: AppRoutes.signUp.routeName,
      builder: (_, _) => const Scaffold(body: Text('sign-up stub')),
    ),
    GoRoute(
      path: AppRoutes.signIn.path,
      name: AppRoutes.signIn.routeName,
      builder: (_, _) => const Scaffold(body: Text('sign-in stub')),
    ),
  ],
);
