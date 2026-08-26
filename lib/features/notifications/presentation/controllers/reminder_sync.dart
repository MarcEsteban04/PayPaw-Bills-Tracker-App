import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/current_user_provider.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import '../../../bills/presentation/controllers/bill_detail_provider.dart';
import '../../../subscriptions/domain/entities/subscription.dart';
import '../../../subscriptions/domain/entities/subscription_notice.dart';
import '../../../subscriptions/presentation/controllers/subscription_providers.dart';
import '../../domain/entities/bill_notice.dart';
import '../../domain/entities/bill_reminder_override.dart';
import '../../domain/entities/reminder_preferences.dart';
import '../../domain/entities/scheduled_notice.dart';
import 'notification_providers.dart';

/// Keeps the device's scheduled reminders matching the bills.
///
/// ## Why a listener and not a call at each write site
///
/// Every write already invalidates `billsProvider` — that is how the list, the
/// totals and every dashboard figure stay honest. Hanging the reminder rebuild
/// off the same signal means adding a bill, editing one, recording a payment,
/// archiving, deleting and generating a recurring occurrence are *all* covered
/// without any of those six code paths knowing reminders exist.
///
/// The alternative is six call sites that each have to remember, and the one
/// that forgets leaves a reminder scheduled for a bill that was paid last week.
/// That failure is invisible until the day it fires.
///
/// ## It is fire-and-forget on purpose
///
/// Nothing waits for the schedule to be written and nothing shows an error if it
/// is not. Rescheduling is bookkeeping the user did not ask for: a payment that
/// was recorded successfully should not report a failure because the notification
/// scheduler was busy, and there is no action the user could take about it.
/// The next write, or the next launch, tries again.
class ReminderSync {
  const ReminderSync(this._ref);

  final Ref _ref;

  /// Rebuilds the whole schedule from the bills as they are now.
  ///
  /// Never throws. See the note above: this is bookkeeping nobody asked for, and
  /// an exception escaping here would surface as an unhandled error on a screen
  /// that was doing something else entirely.
  Future<void> rebuild() async {
    try {
      final List<BillWithStatus>? bills = _ref.read(billsProvider).value;
      if (bills == null) {
        // Bills have not arrived, or the fetch failed. Cancelling on the
        // strength of an empty read would silently clear every reminder the
        // user has because their connection dropped.
        return;
      }

      final ReminderPreferences preferences = await _ref.read(
        reminderPreferencesProvider.future,
      );
      final Map<String, BillReminderOverride> overrides = await _ref.read(
        billReminderOverridesProvider.future,
      );

      // The device clock, and here it is the right source. Every other date in
      // this app comes from the database because a wrong phone clock would
      // disagree with the statuses beside it — but the scheduler *is* the device
      // clock, so a notice has to be placed against the same one it will be
      // woken by.
      final DateTime now = DateTime.now();

      // Subscriptions may not have loaded, and that is not a reason to stop:
      // this rebuild fires off `billsProvider`, which changes far more often
      // than the subscription list does. An empty read here costs the
      // subscription notices until the next rebuild; refusing to schedule the
      // bill reminders as well would cost both.
      final List<Subscription> subscriptions =
          _ref.read(subscriptionsProvider).value ?? const <Subscription>[];

      await _ref.read(notificationServiceProvider).replaceScheduledNotices(
        <ScheduledNotice>[
          ...BillNoticeSchedule.of(
            bills,
            preferences: preferences,
            overrides: overrides,
            now: now,
          ),
          // One call, one schedule. `replaceScheduledNotices` cancels
          // everything pending before it lays down what it is given, so a
          // second call would wipe the first — silently, and discovered days
          // later by a reminder that never arrived.
          ...SubscriptionNoticeSchedule.of(
            subscriptions,
            preferences: preferences,
            now: now,
          ),
        ],
      );
    } on Object catch (error) {
      debugPrint('PayPaw: could not rebuild the reminder schedule ($error)');
    }
  }

  /// Rebuilds the schedule, but only if the device has changed timezone.
  ///
  /// Called when the app comes back to the foreground, because that is the one
  /// moment PayPaw can notice. Android broadcasts `TIMEZONE_CHANGED`, but
  /// `flutter_local_notifications` only listens for boot and package-replaced —
  /// so a phone that lands somewhere new keeps every alarm at the instant it was
  /// set, and a 9am reminder arrives at one in the morning.
  ///
  /// Rebuilding *only* on a change rather than on every resume is deliberate:
  /// resume is frequent, cancelling and re-laying a dozen alarms is not free,
  /// and nothing else about the schedule goes stale while the app is in the
  /// background. Every write already rebuilds through the listeners below.
  ///
  /// It cannot help a user who never opens the app after landing. That is the
  /// honest limit of doing this without a background receiver of our own, and
  /// the failure it leaves — a reminder some hours out on the day after a
  /// flight — is smaller than the one it fixes.
  Future<void> rebuildIfTimezoneChanged() async {
    try {
      final bool moved = await _ref
          .read(notificationServiceProvider)
          .refreshTimezone();

      if (moved) {
        await rebuild();
      }
    } on Object catch (error) {
      debugPrint('PayPaw: could not re-read the device timezone ($error)');
    }
  }

  /// Clears every scheduled reminder.
  ///
  /// For signing out. The reminders on the device belong to the account that
  /// was signed in — leaving them would mean the next person to use the phone
  /// being told about somebody else's rent, by name and amount.
  Future<void> clear() async {
    try {
      await _ref
          .read(notificationServiceProvider)
          .replaceScheduledNotices(const <BillNotice>[]);
    } on Object catch (error) {
      debugPrint('PayPaw: could not clear the reminder schedule ($error)');
    }
  }
}

/// Watches the bills and the preferences, and rewrites the schedule when either
/// changes.
///
/// A `Provider` with listeners rather than a widget: the schedule has to follow
/// the data whether or not any particular screen is on display, and a rebuild
/// tied to a screen would stop happening the moment the user navigated away.
///
/// Kept alive by `PayPawApp` watching it once.
final Provider<ReminderSync> reminderSyncProvider = Provider<ReminderSync>((
  Ref ref,
) {
  final ReminderSync sync = ReminderSync(ref);

  // Nothing before a session, deliberately.
  //
  // Subscribing to `billsProvider` is what *creates* it, so wiring these up
  // unconditionally would have the app fetching bills on the welcome and
  // sign-in screens — a request that can only fail, made on every launch, before
  // there is an account to make it for.
  if (ref.watch(currentUserProvider).value == null) {
    // And on the way out, the reminders go with the session. They name the
    // previous account's bills and amounts, and the next person to pick up the
    // phone should not be told about them.
    unawaited(sync.clear());

    return sync;
  }

  // `fireImmediately` is deliberate on the bills listener: the first successful
  // load is itself a reason to rebuild, and it is the one that covers a fresh
  // launch after the phone rescheduled nothing.
  ref.listen(billsProvider, (_, _) => sync.rebuild(), fireImmediately: true);
  ref.listen(reminderPreferencesProvider, (_, _) => sync.rebuild());
  ref.listen(billReminderOverridesProvider, (_, _) => sync.rebuild());

  // Coming back to the foreground is the one moment the app can notice that the
  // phone has moved. See [ReminderSync.rebuildIfTimezoneChanged] — it does
  // nothing at all unless the zone actually changed, which is almost always.
  final AppLifecycleListener lifecycle = AppLifecycleListener(
    onResume: () => unawaited(sync.rebuildIfTimezoneChanged()),
  );
  ref.onDispose(lifecycle.dispose);

  return sync;
});
