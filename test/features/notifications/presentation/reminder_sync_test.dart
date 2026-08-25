import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/auth/domain/entities/authenticated_user.dart';
import 'package:paypaw/features/auth/presentation/controllers/current_user_provider.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_detail_provider.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_repository_provider.dart';
import 'package:paypaw/features/notifications/domain/entities/bill_notice.dart';
import 'package:paypaw/features/notifications/domain/entities/bill_reminder_override.dart';
import 'package:paypaw/features/notifications/domain/entities/reminder_preferences.dart';
import 'package:paypaw/features/notifications/presentation/controllers/notification_providers.dart';
import 'package:paypaw/features/notifications/presentation/controllers/reminder_sync.dart';

import '../../bills/helpers/fake_bill_repository.dart';
import '../helpers/fake_notification_service.dart';

/// Keeping the device's schedule matching the bills.
///
/// The rules for *which* reminders exist are tested next door as a pure
/// function. What this covers is the plumbing that keeps them current — and the
/// failure it exists to prevent is a reminder left scheduled for a bill that was
/// paid last week, which nobody sees until the morning it fires.
void main() {
  // A binding, because the timezone watcher below is an AppLifecycleListener and
  // there is no lifecycle to listen to without one.
  TestWidgetsFlutterBinding.ensureInitialized();

  BillWithStatus bill({
    String id = 'bill-1',
    BillStatus? status = BillStatus.upcoming,
  }) => BillWithStatus(
    bill: Bill(
      id: id,
      userId: 'user-1',
      name: 'Meralco',
      amount: const Money.php(150000),
      // Far enough out that every default offset is still in the future,
      // whenever this test happens to run.
      dueOn: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: status,
    paid: const Money.php(0),
    outstanding: const Money.php(150000),
    today: DateTime.now(),
  );

  late FakeNotificationService notifications;
  late FakeBillRepository billRepository;

  Future<ProviderContainer> containerWith(
    List<BillWithStatus> bills, {
    bool signedIn = false,
    bool absorbSetup = true,
  }) async {
    notifications = FakeNotificationService();
    billRepository = FakeBillRepository(bills: bills);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        billRepositoryProvider.overrideWithValue(billRepository),
        reminderPreferencesProvider.overrideWith(
          (Ref ref) async => const ReminderPreferences(),
        ),
        // Overridden even though most tests here have no overrides to speak of:
        // the real one reaches Supabase, and a rebuild that throws is a rebuild
        // that never reaches the service being asserted on.
        billReminderOverridesProvider.overrideWith(
          (Ref ref) async => const <String, BillReminderOverride>{},
        ),
        // Only where a test needs the provider's listeners wired up. Without a
        // session it returns early by design — see reminderSyncProvider.
        if (signedIn)
          currentUserProvider.overrideWith(
            (Ref ref) => Stream<AuthenticatedUser?>.value(
              const AuthenticatedUser(
                id: 'user-1',
                email: 'marc@example.com',
                hasConfirmedEmail: true,
              ),
            ),
          ),
      ],
    );
    addTearDown(container.dispose);

    // Read once and reset the record.
    //
    // There is no session in these containers, and the provider's own body
    // clears the schedule when there is none — correctly, and asserted on its
    // own below. Absorbing it here keeps every other test counting only what it
    // asked for.
    // Listened to rather than read once. The provider rebuilds when the session
    // arrives — a StreamProvider has not emitted at the moment this runs — and a
    // provider nothing is subscribed to is not rebuilt at all, so its lifecycle
    // listener would never be attached.
    final ProviderSubscription<ReminderSync> subscription = container.listen(
      reminderSyncProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    // Let the session settle before the record is reset. The provider clears the
    // schedule once for the absent session and again when the stream confirms
    // it — both correct, and both noise in every test below.
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(Duration.zero);

    // Not for the tests that are *about* what happens without being asked: the
    // reset would wipe the very rebuild they exist to observe.
    if (absorbSetup) {
      notifications.rebuilds.clear();
      notifications.scheduled = const <BillNotice>[];
    }

    return container;
  }

  group('rebuilding', () {
    test('writes both kinds for a bill that wants them', () async {
      final ProviderContainer container = await containerWith(<BillWithStatus>[
        bill(),
      ]);
      await container.read(billsProvider.future);

      await container.read(reminderSyncProvider).rebuild();

      // Three reminders from the default {3, 1, 0}, and four overdue steps.
      // The bill is thirty days out, so every one of the seven is still ahead.
      expect(notifications.scheduled, hasLength(7));
      expect(
        notifications.scheduled
            .where((BillNotice n) => n.kind == BillNoticeKind.reminder)
            .map((BillNotice n) => n.days)
            .toList(),
        <int>[3, 1, 0],
      );
      expect(
        notifications.scheduled
            .where((BillNotice n) => n.kind == BillNoticeKind.overdue)
            .map((BillNotice n) => n.days)
            .toList(),
        BillNoticeSchedule.overdueDays,
      );
    });

    test('and leaves out the bills that do not', () async {
      final ProviderContainer container = await containerWith(<BillWithStatus>[
        bill(status: BillStatus.paid),
      ]);
      await container.read(billsProvider.future);

      await container.read(reminderSyncProvider).rebuild();

      expect(notifications.scheduled, isEmpty);
    });

    test('it replaces rather than adds to what is already there', () async {
      // The whole reason the service takes the complete set. Reconciling instead
      // would need an accurate record of what was scheduled, and the only one
      // lives in the platform and is rebuilt from scratch after a reboot.
      final ProviderContainer container = await containerWith(<BillWithStatus>[
        bill(),
      ]);
      await container.read(billsProvider.future);

      await container.read(reminderSyncProvider).rebuild();
      await container.read(reminderSyncProvider).rebuild();

      expect(notifications.rebuilds, hasLength(2));
      expect(notifications.scheduled, hasLength(7));
    });
  });

  group('when it cannot', () {
    test('a failed bills read schedules nothing, and cancels nothing', () async {
      // Cancelling on the strength of an empty read would silently clear every
      // reminder the user has because their connection dropped.
      final ProviderContainer container = await containerWith(<BillWithStatus>[
        bill(),
      ]);

      // Not awaited: the bills have never resolved, so the value is null.
      await container.read(reminderSyncProvider).rebuild();

      expect(notifications.rebuilds, isEmpty);
    });

    test('and a thrown error never escapes', () async {
      // Rescheduling is bookkeeping the user did not ask for. An exception here
      // would surface as an unhandled error on a screen doing something else —
      // recording a payment, say, which had already succeeded.
      final ProviderContainer container = ProviderContainer(
        overrides: [
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          billRepositoryProvider.overrideWithValue(
            FakeBillRepository(bills: <BillWithStatus>[bill()]),
          ),
          reminderPreferencesProvider.overrideWith(
            (Ref ref) async => throw StateError('no preferences'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(billsProvider.future);

      await expectLater(
        container.read(reminderSyncProvider).rebuild(),
        completes,
      );
    });
  });

  group('signing out', () {
    test('clears the schedule as soon as there is no session', () async {
      // Not waited for and not asked for: the provider does it the moment it is
      // read without a user. Asserted on a raw container, before the reset every
      // other test here relies on.
      final FakeNotificationService service = FakeNotificationService();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          notificationServiceProvider.overrideWithValue(service),
          billRepositoryProvider.overrideWithValue(FakeBillRepository()),
        ],
      );
      addTearDown(container.dispose);

      container.read(reminderSyncProvider);
      await Future<void>.delayed(Duration.zero);

      expect(service.rebuilds, hasLength(1));
      expect(service.rebuilds.single, isEmpty);
    });

    test('and on request', () async {
      // The reminders name the previous account's bills and amounts. The next
      // person to pick up the phone should not be told about them.
      final ProviderContainer container = await containerWith(<BillWithStatus>[
        bill(),
      ]);
      await container.read(billsProvider.future);
      await container.read(reminderSyncProvider).rebuild();
      expect(notifications.scheduled, isNotEmpty);

      await container.read(reminderSyncProvider).clear();

      expect(notifications.scheduled, isEmpty);
    });
  });

  group('when the phone changes timezone', () {
    /// Sends the app away and brings it back, which is the only moment PayPaw
    /// can notice it has moved. A transition straight to resumed from resumed is
    /// not a resume, so it goes out first.
    Future<void> resume(WidgetsBinding binding) async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
    }

    test('a resume asks whether the zone moved', () async {
      final ProviderContainer container = await containerWith(<BillWithStatus>[
        bill(),
      ], signedIn: true);
      await container.read(billsProvider.future);
      notifications.rebuilds.clear();

      await resume(WidgetsBinding.instance);

      expect(notifications.timezoneReads, 1);
    });

    test('and rebuilds when it did', () async {
      // The failure this exists to fix: every alarm was placed against the old
      // zone, so a 9am reminder set in Manila arrives at one in the morning in
      // London.
      final ProviderContainer container = await containerWith(<BillWithStatus>[
        bill(),
      ], signedIn: true);
      await container.read(billsProvider.future);
      notifications.rebuilds.clear();
      notifications.timezoneMoved = true;

      await resume(WidgetsBinding.instance);

      expect(notifications.rebuilds, hasLength(1));
      expect(notifications.scheduled, hasLength(7));
    });

    test('but not when it did not', () async {
      // Resume is frequent and re-laying a dozen alarms is not free. Nothing
      // else about the schedule goes stale in the background — every write
      // rebuilds through the provider's own listeners.
      final ProviderContainer container = await containerWith(<BillWithStatus>[
        bill(),
      ], signedIn: true);
      await container.read(billsProvider.future);
      notifications.rebuilds.clear();

      await resume(WidgetsBinding.instance);

      expect(notifications.rebuilds, isEmpty);
    });

    test('and asks nothing at all once the session is gone', () async {
      // The listener belongs to the signed-in half of the provider. A signed-out
      // app has no schedule to correct, and asking would be a platform call on
      // every resume of the sign-in screen.
      final ProviderContainer container = await containerWith(<BillWithStatus>[
        bill(),
      ]);
      notifications.timezoneMoved = true;

      await resume(WidgetsBinding.instance);

      expect(notifications.timezoneReads, 0);
      expect(container.read(reminderSyncProvider), isNotNull);
    });

    test('the check itself survives a service that throws', () async {
      // Same rule as every other path here: rescheduling is bookkeeping nobody
      // asked for, and an exception escaping would surface as an unhandled error
      // on whatever screen the user just came back to.
      final ProviderContainer container = await containerWith(<BillWithStatus>[
        bill(),
      ]);
      notifications.failTimezoneRead = true;

      await expectLater(
        container.read(reminderSyncProvider).rebuildIfTimezoneChanged(),
        completes,
      );
    });
  });

  group('a bill nobody typed', () {
    test('gets its reminders without being asked for', () async {
      // The recurring case, end to end from here. `billsProvider` runs
      // generation before it fetches, so an occurrence the database created
      // overnight — or one this launch just materialised — is in the set the
      // schedule is built from. Nothing in the recurring feature knows that
      // reminders exist, and nothing needs to.
      //
      // No explicit rebuild: the listener's `fireImmediately` is the whole
      // mechanism, and this is the test that would fail if it were dropped.
      final ProviderContainer container = await containerWith(
        <BillWithStatus>[bill(id: 'generated-1')],
        signedIn: true,
        absorbSetup: false,
      );

      await container.read(billsProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(notifications.rebuilds, isNotEmpty);
      expect(
        notifications.scheduled.map((BillNotice n) => n.billId).toSet(),
        <String>{'generated-1'},
      );
    });

    test('and a later occurrence replaces the schedule rather than adding', () async {
      // A month on, the old occurrence is settled and a new one exists. The
      // schedule is rewritten whole, so the settled bill's reminders go with it
      // — the alternative is an alert about a bill that was paid in September.
      final ProviderContainer container = await containerWith(
        <BillWithStatus>[
          bill(id: 'occurrence-1', status: BillStatus.paid),
          bill(id: 'occurrence-2'),
        ],
        signedIn: true,
        absorbSetup: false,
      );

      await container.read(billsProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(
        notifications.scheduled.map((BillNotice n) => n.billId).toSet(),
        <String>{'occurrence-2'},
      );
    });
  });
}
