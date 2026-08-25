import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/notifications/domain/entities/notification_permission.dart';
import 'package:paypaw/features/notifications/domain/entities/reminder_preferences.dart';
import 'package:paypaw/features/notifications/domain/entities/reminder_time.dart';
import 'package:paypaw/features/notifications/presentation/controllers/notification_providers.dart';
import 'package:paypaw/features/notifications/presentation/screens/reminder_settings_screen.dart';

import '../helpers/fake_notification_service.dart';
import '../helpers/fake_reminder_preferences_repository.dart';

/// The screen onboarding has been promising since Sprint 11B.
///
/// It has no Save button — every control writes on change — so the tests here
/// are almost all one question: did the tap actually reach the repository. A
/// control that looks like it took and wrote nothing is the whole failure mode
/// this shape introduces.
void main() {
  late FakeReminderPreferencesRepository repository;

  Future<void> pumpScreen(
    WidgetTester tester, {
    ReminderPreferences preferences = const ReminderPreferences(),
    NotificationPermission permission = NotificationPermission.granted,
  }) async {
    repository = FakeReminderPreferencesRepository(preferences: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderPreferencesRepositoryProvider.overrideWithValue(repository),
          reminderPreferencesProvider.overrideWith(
            (Ref ref) => repository.fetch(),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(permissionState: permission),
          ),
          notificationPermissionProvider.overrideWith(
            (Ref ref) async => permission,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ReminderSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('what it shows', () {
    testWidgets('the stored settings, not the defaults', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        preferences: const ReminderPreferences(
          daysBefore: <int>[7],
          timeOfDay: ReminderTime(hour: 18, minute: 30),
        ),
      );

      expect(find.text('6:30 PM'), findsOneWidget);
    });

    testWidgets('the permission card when posting is blocked', (
      WidgetTester tester,
    ) async {
      // Above the settings, not below: a screen of switches that cannot produce
      // a notification is worth saying so before the user arranges anything.
      await pumpScreen(tester, permission: NotificationPermission.denied);

      expect(find.text('Reminders are off'), findsOneWidget);
    });

    testWidgets('and not once it is granted', (WidgetTester tester) async {
      // Granted is the helper's default, since it is what every other test here
      // needs — a permission card in the way would hide half the screen.
      await pumpScreen(tester);

      expect(find.text('Reminders are off'), findsNothing);
    });

    testWidgets('what the master switch actually covers', (
      WidgetTester tester,
    ) async {
      // It reads as "reminders" but it silences overdue alerts too, and a user
      // who turns it off and then misses a late bill deserves to have been told.
      await pumpScreen(tester);

      expect(
        find.text('Turns off reminders and overdue alerts together.'),
        findsOneWidget,
      );
    });

    testWidgets('and that overdue alerts are a rule, not a setting', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('If a bill goes unpaid'), findsOneWidget);
      expect(find.textContaining('1, 3, 7, 14 days'), findsOneWidget);
    });
  });

  group('what a tap writes', () {
    testWidgets('the master switch, immediately', (WidgetTester tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Remind me about bills'));
      await tester.pumpAndSettle();

      expect(repository.saved.single.isEnabled, isFalse);
    });

    testWidgets('turning an offset on keeps the ones already chosen', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('7 days before'));
      await tester.pumpAndSettle();

      expect(repository.saved.single.orderedOffsets, <int>[7, 3, 1, 0]);
    });

    testWidgets('and turning one off removes only that one', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('3 days before'));
      await tester.pumpAndSettle();

      expect(repository.saved.single.orderedOffsets, <int>[1, 0]);
    });

    testWidgets('but the last offset cannot be removed', (
      WidgetTester tester,
    ) async {
      // An empty set means reminders that are switched on and never arrive,
      // which is worse than either honest state. Turning them all off is what
      // the switch above is for, and it says so.
      await pumpScreen(
        tester,
        preferences: const ReminderPreferences(daysBefore: <int>[3]),
      );

      await tester.tap(find.text('3 days before'));
      await tester.pumpAndSettle();

      expect(repository.saved, isEmpty);
    });
  });

  group('when reminders are off', () {
    testWidgets('the offsets are visible but cannot be changed', (
      WidgetTester tester,
    ) async {
      // Left on screen rather than hidden, so turning the switch back on does
      // not reveal a section that was never seen.
      await pumpScreen(
        tester,
        preferences: const ReminderPreferences(isEnabled: false),
      );

      expect(find.text('3 days before'), findsOneWidget);

      await tester.tap(find.text('3 days before'));
      await tester.pumpAndSettle();

      expect(repository.saved, isEmpty);
    });

    testWidgets('and the switch is the way back', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        preferences: const ReminderPreferences(isEnabled: false),
      );

      await tester.tap(find.text('Remind me about bills'));
      await tester.pumpAndSettle();

      expect(repository.saved.single.isEnabled, isTrue);
    });
  });

  testWidgets('a rejected write is said out loud', (WidgetTester tester) async {
    // The cost of having no Save button: there is no control left sitting there
    // to retry, so a silent failure reads as the tap never registering.
    await pumpScreen(tester);
    repository.failWith = const NetworkException();

    await tester.tap(find.text('Remind me about bills'));
    await tester.pumpAndSettle();

    expect(
      find.text('No internet connection. Check your network and try again.'),
      findsOneWidget,
    );
  });
}
