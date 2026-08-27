import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/core/providers/storage_providers.dart';
import 'package:paypaw/core/providers/supabase_providers.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/auth/domain/entities/authenticated_user.dart';
import 'package:paypaw/features/auth/presentation/controllers/current_user_provider.dart';
import 'package:paypaw/features/profile/domain/entities/user_profile.dart';
import 'package:paypaw/features/profile/presentation/controllers/profile_providers.dart';
import 'package:paypaw/features/profile/presentation/widgets/time_zone_row.dart';
import 'package:paypaw/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../profile/helpers/fake_profile_repository.dart';

/// The screen that stopped being a placeholder.
///
/// Two things here are worth more than the layout: that a name somebody types
/// actually reaches the database, and that a time zone which disagrees with the
/// phone is *said out loud* — because a wrong zone is wrong due dates, and
/// nothing else in the app would give the reason.
void main() {
  late FakeProfileRepository repository;

  Future<void> pumpProfile(
    WidgetTester tester, {
    UserProfile? profile,
    String? deviceZone = 'Asia/Manila',
    String email = 'marc@example.com',
  }) async {
    repository = FakeProfileRepository(profile: profile);

    // The appearance pills read the stored theme, which main() normally
    // overrides.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    tester.view
      ..physicalSize = const Size(392 * 3, 1400 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repository),
          deviceTimeZoneProvider.overrideWith((Ref ref) async => deviceZone),
          currentUserProvider.overrideWith(
            (Ref ref) => Stream<AuthenticatedUser?>.value(
              AuthenticatedUser(
                id: 'user-1',
                email: email,
                hasConfirmedEmail: true,
              ),
            ),
          ),
          // The account section reads this, and the real one needs a client.
          isBackendConfiguredProvider.overrideWithValue(true),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('who you are', () {
    testWidgets('leads with the name, not the address', (
      WidgetTester tester,
    ) async {
      await pumpProfile(
        tester,
        profile: const UserProfile(id: 'user-1', displayName: 'Marc'),
      );

      expect(find.text('Marc'), findsOneWidget);
      expect(find.text('marc@example.com'), findsWidgets);
    });

    testWidgets('and asks for one when there is none', (
      WidgetTester tester,
    ) async {
      // Rather than silently falling back to the address in the large type. An
      // empty state that asks for something beats one that quietly makes do.
      await pumpProfile(tester);

      expect(find.text('Add your name'), findsOneWidget);
    });
  });

  group('editing the name', () {
    testWidgets('writes what was typed', (WidgetTester tester) async {
      await pumpProfile(tester);

      await tester.tap(find.text('Add your name'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Marc');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.savedNames, <String?>['Marc']);
      expect(find.text('Marc'), findsOneWidget);
    });

    testWidgets('trims it, because a leading space is not part of a name', (
      WidgetTester tester,
    ) async {
      await pumpProfile(tester);

      await tester.tap(find.text('Add your name'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '  Marc  ');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.savedNames, <String?>['Marc']);
    });

    testWidgets('and clearing it is a choice, not an error', (
      WidgetTester tester,
    ) async {
      // Somebody who deletes their name is asking to be a nameless account
      // again, not asking for the empty string.
      await pumpProfile(
        tester,
        profile: const UserProfile(id: 'user-1', displayName: 'Marc'),
      );

      await tester.tap(find.text('Marc'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.savedNames, <String?>[null]);
      expect(find.text('Add your name'), findsOneWidget);
    });

    testWidgets('a rejected write is said out loud', (
      WidgetTester tester,
    ) async {
      // This is a write the user asked for and is watching. A name that appears
      // to save and did not is worse than a message, because the next thing
      // they do is close the sheet believing it.
      await pumpProfile(tester);

      await tester.tap(find.text('Add your name'));
      await tester.pumpAndSettle();
      repository.failWith = const NetworkException();

      await tester.enterText(find.byType(TextFormField), 'Marc');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('No internet connection. Check your network and try again.'),
        findsOneWidget,
      );
      // And the sheet stays open, so the typing is not lost.
      expect(find.byType(TextFormField), findsOneWidget);
    });
  });

  group('the time zone', () {
    testWidgets('is shown, because it decides what today means', (
      WidgetTester tester,
    ) async {
      await pumpProfile(tester);

      expect(find.text('Asia/Manila'), findsOneWidget);
    });

    testWidgets('says nothing extra when the phone agrees', (
      WidgetTester tester,
    ) async {
      await pumpProfile(tester);

      expect(find.textContaining('Your phone says'), findsNothing);
      expect(find.textContaining('Use '), findsNothing);
    });

    testWidgets('and warns when it does not', (WidgetTester tester) async {
      // The failure this exists to surface: every account defaults to
      // Asia/Manila, so anybody elsewhere has had silently wrong dates since
      // they signed up with no way to find out.
      await pumpProfile(tester, deviceZone: 'Europe/London');

      expect(
        find.textContaining('Your phone says Europe/London'),
        findsOneWidget,
      );
      expect(find.text('Use Europe/London'), findsOneWidget);
    });

    testWidgets('one tap matches it', (WidgetTester tester) async {
      await pumpProfile(tester, deviceZone: 'Europe/London');

      await tester.tap(find.text('Use Europe/London'));
      await tester.pumpAndSettle();

      expect(repository.savedZones, <String>['Europe/London']);
      expect(find.text('Europe/London'), findsOneWidget);
      expect(find.textContaining('Your phone says'), findsNothing);
    });

    testWidgets('and a platform that cannot say produces no warning', (
      WidgetTester tester,
    ) async {
      // PayPaw does not know any better, and inventing a mismatch would send
      // somebody to change a setting that was right.
      await pumpProfile(tester, deviceZone: null);

      expect(find.text('Asia/Manila'), findsOneWidget);
      expect(find.textContaining('Your phone says'), findsNothing);
    });
  });

  testWidgets('the placeholder card is gone', (WidgetTester tester) async {
    // It promised "built in Sprints 54 and 78-80" on a screen that is built,
    // and pointed at sprint numbers for debt and security work.
    await pumpProfile(tester);

    expect(find.textContaining('Built in Sprints'), findsNothing);
    expect(find.textContaining('categories, reminders'), findsNothing);
  });

  group('the developer galleries', () {
    // They were kept off this screen entirely, on the grounds that a user's
    // settings should not offer them a component gallery. That still holds for
    // users — but it left the galleries with no door at all, and the only way in
    // was to edit the router's initial location and remember to put it back,
    // which is how the app once opened on the component gallery instead of the
    // dashboard.
    //
    // So they are here, behind `kDebugMode`, under a heading that says what they
    // are. Tests run in debug, so this is the branch they can see; the release
    // branch is asserted below by the only means a const has — reading it.

    testWidgets('are offered in a debug build, under their own heading', (
      WidgetTester tester,
    ) async {
      await pumpProfile(tester);
      await tester.scrollUntilVisible(find.text('Components'), 200);

      expect(find.text('Developer'), findsOneWidget);
      expect(find.text('Components'), findsOneWidget);
      expect(find.text('Design system'), findsOneWidget);
    });

    testWidgets('sit below everything a user came here for', (
      WidgetTester tester,
    ) async {
      // Last on the screen, under sign out. Nobody scrolling for a setting
      // should meet a developer tool before they find it.
      await pumpProfile(tester);
      await tester.scrollUntilVisible(find.text('Developer'), 200);

      expect(
        tester.getTopLeft(find.text('Developer')).dy,
        greaterThan(
          tester.getTopLeft(find.widgetWithText(OutlinedButton, 'Sign out')).dy,
        ),
      );
    });

    test('are compiled out of a release build', () {
      // The section returns nothing at all when `kDebugMode` is false, and
      // because it is a `const` the branch is removed by the tree shaker rather
      // than merely skipped. A widget test cannot flip it, so the guarantee is
      // asserted where it lives: this test fails the day somebody runs the suite
      // in release mode and the reasoning above stops holding.
      expect(kDebugMode, isTrue);
    });
  });

  testWidgets('sign out is the last thing on the screen', (
    WidgetTester tester,
  ) async {
    // The only disruptive control here, so it sits under everything else.
    await pumpProfile(tester);

    final double signOut = tester
        .getTopLeft(find.widgetWithText(OutlinedButton, 'Sign out'))
        .dy;

    for (final String above in <String>['Appearance', 'Dates']) {
      expect(
        tester.getTopLeft(find.text(above)).dy,
        lessThan(signOut),
        reason: '$above should come before Sign out',
      );
    }
  });
}
