import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/notifications/domain/entities/bill_reminder_override.dart';
import 'package:paypaw/features/notifications/domain/entities/reminder_preferences.dart';
import 'package:paypaw/features/notifications/domain/entities/reminder_time.dart';
import 'package:paypaw/features/notifications/presentation/controllers/notification_providers.dart';
import 'package:paypaw/features/notifications/presentation/widgets/bill_reminder_sheet.dart';

import '../helpers/fake_reminder_preferences_repository.dart';

/// One bill's departure from the defaults.
///
/// The rule the whole sheet exists to express is that **inherit is a state**:
/// a bill left alone keeps following the defaults forever, rather than being
/// frozen at whatever they said the day it was opened. Everything below is a
/// way of getting that wrong.
void main() {
  late FakeReminderPreferencesRepository repository;

  final BillWithStatus item = BillWithStatus(
    bill: Bill(
      id: 'bill-1',
      userId: 'user-1',
      name: 'Meralco',
      amount: const Money.php(150000),
      dueOn: DateTime(2026, 9, 10),
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: BillStatus.upcoming,
    paid: const Money.php(0),
    outstanding: const Money.php(150000),
    today: DateTime(2026, 8, 25),
  );

  Future<void> pumpSheet(
    WidgetTester tester, {
    ReminderPreferences defaults = const ReminderPreferences(),
    BillReminderOverride? stored,
  }) async {
    repository = FakeReminderPreferencesRepository(
      preferences: defaults,
      overrides: stored == null
          ? null
          : <String, BillReminderOverride>{stored.billId: stored},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderPreferencesRepositoryProvider.overrideWithValue(repository),
          reminderPreferencesProvider.overrideWith(
            (Ref ref) => repository.fetch(),
          ),
          billReminderOverridesProvider.overrideWith(
            (Ref ref) => repository.fetchOverrides(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () =>
                    showBillReminderSheet(context: context, item: item),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> turnOnCustom(WidgetTester tester) async {
    await tester.tap(find.text('Use different settings'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  group('what it opens on', () {
    testWidgets('following the defaults, for a bill never touched', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester);

      expect(
        find.text('This bill follows your reminder settings.'),
        findsOneWidget,
      );
    });

    testWidgets('and on the stored override, for a bill that has one', (
      WidgetTester tester,
    ) async {
      await pumpSheet(
        tester,
        stored: const BillReminderOverride(
          billId: 'bill-1',
          timeOfDay: ReminderTime(hour: 18, minute: 30),
        ),
      );

      expect(find.text('This bill ignores your defaults.'), findsOneWidget);
      expect(find.text('6:30 PM'), findsOneWidget);
    });

    testWidgets('showing the inherited settings for the fields it leaves', (
      WidgetTester tester,
    ) async {
      // The override above sets a time and nothing else, so the days shown have
      // to be the defaults — not an empty selection the user never chose.
      await pumpSheet(
        tester,
        defaults: const ReminderPreferences(daysBefore: <int>[7]),
        stored: const BillReminderOverride(
          billId: 'bill-1',
          timeOfDay: ReminderTime(hour: 18, minute: 30),
        ),
      );

      expect(find.text('7 days before'), findsOneWidget);
    });

    testWidgets('and the bill it is about, since it is opened from a list', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester);

      expect(find.text('Meralco'), findsOneWidget);
    });
  });

  group('turning customisation on', () {
    testWidgets('copies the defaults in as a starting point', (
      WidgetTester tester,
    ) async {
      // Not an empty rule. A user opening "customise" wants to change one thing
      // about what they already have, and an empty override is one the
      // repository would delete — so the switch would appear to do nothing.
      await pumpSheet(
        tester,
        defaults: const ReminderPreferences(
          daysBefore: <int>[7],
          timeOfDay: ReminderTime(hour: 18, minute: 30),
        ),
      );

      await turnOnCustom(tester);
      await save(tester);

      expect(
        repository.savedOverrides.single,
        const BillReminderOverride(
          billId: 'bill-1',
          isEnabled: true,
          daysBefore: <int>[7],
          timeOfDay: ReminderTime(hour: 18, minute: 30),
        ),
      );
    });

    testWidgets('and unlocks the controls it was hiding behind it', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester);

      await tester.tap(find.text('3 days before'));
      await tester.pumpAndSettle();
      await save(tester);

      // Still following the defaults: the tap did nothing, so the sheet saved
      // the deletion an untouched bill means.
      expect(repository.savedOverrides.single.isEmpty, isTrue);
    });
  });

  group('what Save writes', () {
    testWidgets('a changed day set, for a customised bill', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester);
      await turnOnCustom(tester);

      await tester.tap(find.text('7 days before'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(repository.savedOverrides.single.daysBefore, <int>[3, 1, 0, 7]);
    });

    testWidgets('a silenced bill, which is the common override', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester);
      await turnOnCustom(tester);

      await tester.tap(find.text('Remind me about it'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(repository.savedOverrides.single.isEnabled, isFalse);
    });

    testWidgets('and turning customisation back off deletes the row', (
      WidgetTester tester,
    ) async {
      // An override that overrides nothing should not exist — the table has a
      // check constraint saying so, and the repository reads an empty one as a
      // deletion.
      await pumpSheet(
        tester,
        stored: const BillReminderOverride(billId: 'bill-1', isEnabled: false),
      );

      await tester.tap(find.text('Use different settings'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(repository.savedOverrides.single.isEmpty, isTrue);
      expect(repository.overrides, isEmpty);
    });

    testWidgets('then closes, because the sheet is one decision', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester);
      await turnOnCustom(tester);
      await save(tester);

      expect(find.text('Use different settings'), findsNothing);
    });
  });

  testWidgets('the last offset cannot be removed here either', (
    WidgetTester tester,
  ) async {
    await pumpSheet(
      tester,
      defaults: const ReminderPreferences(daysBefore: <int>[3]),
    );
    await turnOnCustom(tester);

    await tester.tap(find.text('3 days before'));
    await tester.pumpAndSettle();
    await save(tester);

    expect(repository.savedOverrides.single.daysBefore, <int>[3]);
  });
}
