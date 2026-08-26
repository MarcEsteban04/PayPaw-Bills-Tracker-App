import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import '../../../notifications/domain/entities/notification_channel.dart';
import '../../../notifications/domain/entities/reminder_preferences.dart';
import '../../../notifications/domain/entities/scheduled_notice.dart';
import '../../../recurring/domain/entities/recurrence_frequency.dart';
import 'subscription.dart';

/// The two things PayPaw has to say about a subscription before money moves.
///
/// Both post to [NotificationChannel.subscriptionNotices] rather than to the
/// bill channels, because they ask for a different decision. A bill reminder
/// says *pay this*; these say *cancel this if you do not want it*.
enum SubscriptionNoticeKind {
  /// A free period is about to end and the card is about to be charged.
  trialEnding,

  /// A plan is about to renew.
  renewal,
}

/// One subscription notification, resolved to a moment.
@immutable
class SubscriptionNotice implements ScheduledNotice {
  const SubscriptionNotice({
    required this.kind,
    required this.subscriptionId,
    required this.provider,
    required this.days,
    required this.firesAt,
    required this.on,
    required this.amount,
  });

  final SubscriptionNoticeKind kind;
  final String subscriptionId;

  /// Who charges. The provider rather than the subscription's own name: it is
  /// what somebody scanning a lock screen recognises, and what they would search
  /// for to cancel.
  final String provider;

  /// How many days before [on] this fires. `0` is the day itself.
  final int days;

  @override
  final DateTime firesAt;

  /// The day the money moves — the trial's end, or the renewal date.
  final DateTime on;

  /// What will be charged, formatted.
  final String amount;

  @override
  String get title => switch (kind) {
    // Says what will *happen*, not what is ending. "Your Apple TV+ trial ends
    // tomorrow" is a fact about a calendar; "starts charging tomorrow" is a
    // fact about money, and only one of them makes somebody open the app.
    SubscriptionNoticeKind.trialEnding => switch (days) {
      0 => '$provider starts charging today',
      1 => '$provider starts charging tomorrow',
      final int d => '$provider starts charging in $d days',
    },
    SubscriptionNoticeKind.renewal => switch (days) {
      0 => '$provider renews today',
      1 => '$provider renews tomorrow',
      final int d => '$provider renews in $d days',
    },
  };

  @override
  String get body =>
      // The amount and the date, then the action. A notice about money leaving
      // that does not say how much is a notice that has to be opened to be
      // useful — which is the one thing a lock screen is meant to save.
      '$amount on ${DateFormat.MMMEd().format(on)} · cancel before then to '
      'avoid it';

  @override
  NotificationChannel get channel => NotificationChannel.subscriptionNotices;

  @override
  int get notificationId => noticeIdFor('$subscriptionId:${kind.name}:$days');

  @override
  String get payload =>
      NoticeTarget.encode(NoticeTargetKind.subscription, subscriptionId);

  @override
  bool operator ==(Object other) =>
      other is SubscriptionNotice &&
      other.kind == kind &&
      other.subscriptionId == subscriptionId &&
      other.days == days &&
      other.firesAt == firesAt;

  @override
  int get hashCode => Object.hash(kind, subscriptionId, days, firesAt);

  @override
  String toString() =>
      'SubscriptionNotice(${kind.name}, $provider, $days, $firesAt)';
}

/// Works out which subscription notifications should currently exist.
///
/// ## What this deliberately does *not* do
///
/// **It does not warn about a monthly subscription renewing.** Two reasons, and
/// the first is the important one.
///
/// A subscription generates bills, the generator materialises them 45 days
/// ahead, and `BillNoticeSchedule` already schedules reminders against them. So
/// "Netflix is due in 3 days" *already arrives*. Adding "Netflix renews in 3
/// days" beside it would be two notifications for one event — and the way a user
/// responds to that is by silencing a channel.
///
/// And a monthly plan renewing is not news. It happened last month, it will
/// happen next month, and the amount is one people have already absorbed. What
/// ambushes somebody is the **annual** subscription they forgot they had, which
/// takes ₱6,000 out of an account eleven months after the last time they thought
/// about it. So renewals are announced only for plans that do not charge
/// monthly, and far enough ahead to actually cancel one.
///
/// ## Trials are the real gap
///
/// A trial has **no bill at all**. `trial_ends_on` is a date on the subscription
/// row and nothing in `bills` corresponds to it, so nothing was ever scheduled
/// against it — and a trial converting silently is the single way subscriptions
/// most reliably take money people did not mean to spend.
abstract final class SubscriptionNoticeSchedule {
  /// Days before a trial converts to warn.
  ///
  /// Three and one. Enough warning to act on, and a second the day before for
  /// somebody who saw the first while doing something else.
  ///
  /// Fixed rather than a setting, for the reason `BillNoticeSchedule.overdueDays`
  /// is fixed: this is not "how much warning do you want about a bill", it is
  /// the app's judgement about a deadline with money on the other side of it.
  static const List<int> trialDays = <int>[3, 1];

  /// Days before a non-monthly plan renews to warn.
  ///
  /// A week, and then two days. Longer than a bill reminder on purpose: a bill
  /// can be paid on the day it is due, and a subscription often *cannot* be
  /// cancelled on the day it renews — providers want notice, support queues take
  /// time, and the cancel page is never where it was last year.
  static const List<int> renewalDays = <int>[7, 2];

  /// The notifications that should be scheduled, soonest first.
  ///
  /// [now] is passed in rather than read from the clock, so this stays pure.
  static List<SubscriptionNotice> of(
    List<Subscription> subscriptions, {
    required ReminderPreferences preferences,
    required DateTime now,
  }) {
    // The same switch bill reminders honour. It reads "reminders", but it is the
    // user asking PayPaw not to notify them — and deciding that this particular
    // message is too important to obey that would be the app knowing better.
    if (!preferences.isEnabled) {
      return const <SubscriptionNotice>[];
    }

    final List<SubscriptionNotice> notices = <SubscriptionNotice>[];

    for (final Subscription subscription in subscriptions) {
      // Paused, finished and deleted-in-spirit subscriptions charge nothing, so
      // warning about them would be warning about money that is not moving.
      if (!subscription.isActive) {
        continue;
      }

      if (subscription.details.trialEndsOn case final DateTime ends
          when subscription.isInTrial(now)) {
        notices.addAll(
          _noticesFor(
            subscription: subscription,
            kind: SubscriptionNoticeKind.trialEnding,
            on: ends,
            offsets: trialDays,
            preferences: preferences,
            now: now,
          ),
        );

        // Not both. A trial that ends and a first charge that follows it are one
        // event to the person being charged, and saying it twice in two wordings
        // is how a useful channel becomes one that gets muted.
        continue;
      }

      // A plan set not to renew is one the user has already dealt with. Telling
      // them it renews would be wrong as well as unwelcome.
      if (!subscription.details.autoRenews) {
        continue;
      }

      // See the note above: monthly plans are covered by their own bills'
      // reminders, and a second notice for the same charge is how a channel
      // earns itself a mute.
      if (_chargesMonthlyOrMoreOften(subscription)) {
        continue;
      }

      notices.addAll(
        _noticesFor(
          subscription: subscription,
          kind: SubscriptionNoticeKind.renewal,
          on: subscription.nextBillingOn,
          offsets: renewalDays,
          preferences: preferences,
          now: now,
        ),
      );
    }

    notices.sort(
      (SubscriptionNotice a, SubscriptionNotice b) =>
          a.firesAt.compareTo(b.firesAt),
    );

    return notices;
  }

  /// Whether this charges at least once a month.
  ///
  /// Weekly and fortnightly count: those generate bills constantly, and their
  /// reminders are already relentless enough without a second voice.
  static bool _chargesMonthlyOrMoreOften(Subscription subscription) =>
      switch (subscription.recurrence.frequency) {
        RecurrenceFrequency.weekly => true,
        RecurrenceFrequency.monthly =>
          subscription.recurrence.intervalCount == 1,
        RecurrenceFrequency.quarterly || RecurrenceFrequency.yearly => false,
      };

  static Iterable<SubscriptionNotice> _noticesFor({
    required Subscription subscription,
    required SubscriptionNoticeKind kind,
    required DateTime on,
    required List<int> offsets,
    required ReminderPreferences preferences,
    required DateTime now,
  }) sync* {
    for (final int days in offsets) {
      final DateTime fires = DateTime(
        on.year,
        on.month,
        on.day - days,
        preferences.timeOfDay.hour,
        preferences.timeOfDay.minute,
      );

      // Already past. The platform would fire an overdue schedule immediately on
      // some Android versions, which turns opening the app into a burst of
      // notifications about deadlines that have gone.
      if (!fires.isAfter(now)) {
        continue;
      }

      yield SubscriptionNotice(
        kind: kind,
        subscriptionId: subscription.id,
        provider: subscription.details.provider,
        days: days,
        firesAt: fires,
        on: on,
        amount: subscription.amount.format(),
      );
    }
  }
}
