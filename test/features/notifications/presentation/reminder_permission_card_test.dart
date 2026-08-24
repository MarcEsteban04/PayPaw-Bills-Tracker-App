import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/notifications/domain/entities/notification_permission.dart';
import 'package:paypaw/features/notifications/presentation/controllers/notification_providers.dart';
import 'package:paypaw/features/notifications/presentation/widgets/reminder_permission_card.dart';

import '../helpers/fake_notification_service.dart';

/// The one piece of notification UI in this sprint.
///
/// Its whole job is the distinction Android will not draw for you: a refusal is
/// **final**, and a button still wired to `requestPermission` after one is a
/// button the user taps and taps while nothing happens.
void main() {
  late FakeNotificationService service;

  Future<void> pumpCard(
    WidgetTester tester,
    NotificationPermission permission,
  ) async {
    service = FakeNotificationService(permissionState: permission);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(service),
          notificationPermissionProvider.overrideWith(
            (Ref ref) async => permission,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ReminderPermissionCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('when it appears', () {
    testWidgets('not at all once permission is granted', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, NotificationPermission.granted);

      expect(find.text('Reminders are off'), findsNothing);
    });

    testWidgets('nor where the platform has none to grant', (
      WidgetTester tester,
    ) async {
      // Below Android 13 there is no runtime gate, so there is nothing this
      // card could do.
      await pumpCard(tester, NotificationPermission.notApplicable);

      expect(find.text('Reminders are off'), findsNothing);
    });

    testWidgets('but it does when nobody has been asked yet', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, NotificationPermission.notRequested);

      expect(find.text('Reminders are off'), findsOneWidget);
    });
  });

  group('before anyone has been asked', () {
    testWidgets('it offers to ask, in terms of what the user gets', (
      WidgetTester tester,
    ) async {
      // "PayPaw requires the notification permission" describes the app's
      // problem. This describes the user's.
      await pumpCard(tester, NotificationPermission.notRequested);

      expect(find.text('Turn on reminders'), findsOneWidget);
      expect(
        find.text('Let PayPaw tell you before a bill is due.'),
        findsOneWidget,
      );
    });

    testWidgets('and the button actually asks', (WidgetTester tester) async {
      await pumpCard(tester, NotificationPermission.notRequested);

      await tester.tap(find.text('Turn on reminders'));
      await tester.pumpAndSettle();

      expect(service.requestCalls, 1);
      expect(service.settingsCalls, 0);
    });
  });

  group('after a refusal', () {
    testWidgets('it stops offering to ask', (WidgetTester tester) async {
      // Android will not show the dialog a second time. A button that still
      // said "Turn on reminders" would do nothing, forever, with no explanation.
      await pumpCard(tester, NotificationPermission.denied);

      expect(find.text('Reminders are off'), findsOneWidget);
      expect(find.text('Turn on reminders'), findsNothing);
      expect(find.text('Open settings'), findsOneWidget);
    });

    testWidgets('and says where the switch is instead', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, NotificationPermission.denied);

      expect(find.textContaining('in Settings'), findsOneWidget);
    });

    testWidgets('and the button goes there, rather than asking again', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, NotificationPermission.denied);

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(service.settingsCalls, 1);
      expect(service.requestCalls, 0);
    });
  });
}
