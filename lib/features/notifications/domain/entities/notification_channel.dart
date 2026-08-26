/// The categories PayPaw posts notifications under.
///
/// ## Why these are a fixed vocabulary
///
/// On Android a channel is not an implementation detail — it is a **row in the
/// user's system settings** with its own toggle, its own sound and its own
/// importance, and once created its importance cannot be raised again from code.
/// So the set has to be decided rather than accumulated, and each one has to be a
/// category a person would plausibly want to silence on its own.
///
/// Two, therefore, and not one per reminder offset. "Remind me 7 days before"
/// and "remind me 1 day before" are the same *kind* of interruption; splitting
/// them would put four near-identical toggles in Settings and make turning
/// reminders off a four-tap job. They are one channel, and which offsets fire is
/// PayPaw's own setting (Sprint 42).
///
/// Overdue is separate because it is a different kind of message. A reminder is
/// a courtesy and a person might reasonably want none; "this is late" is the one
/// notification a bills app exists to send, and someone who silences the first
/// has not asked to silence the second.
///
/// ## They are registered before anything posts to them
///
/// A channel must exist before its first notification, and creating one lazily on
/// the way to posting is a race for no benefit. Registering at startup also means
/// a user can find the toggles and turn a category off *before* being interrupted
/// by it, rather than discovering them afterwards.
///
/// Nothing posts to either channel until Sprints 40 and 41. Until then they are
/// two inert rows in Settings — which is the honest state of things, and better
/// than a reminder arriving from a category the user was never offered.
enum NotificationChannel {
  /// A bill is coming up. Scheduled ahead of the due date.
  billReminders(
    id: 'bill_reminders',
    name: 'Bill reminders',
    description: 'Reminders before a bill is due.',
  ),

  /// A bill is past its due date and still owing.
  overdueBills(
    id: 'overdue_bills',
    name: 'Overdue bills',
    description: 'Alerts when a bill is past its due date.',
  ),

  /// Money is about to leave for a subscription — a trial converting, or a
  /// plan renewing.
  ///
  /// Its own row rather than a third use of the bill channel, because these ask
  /// for a different decision. A bill reminder says *pay this*; a subscription
  /// notice says *cancel this if you do not want it*, and it is worth arriving
  /// even for somebody who has silenced their bill reminders because they pay by
  /// standing order and do not need chasing.
  subscriptionNotices(
    id: 'subscription_notices',
    name: 'Subscription renewals',
    description:
        'Warnings before a free trial converts or a subscription renews.',
  );

  const NotificationChannel({
    required this.id,
    required this.name,
    required this.description,
  });

  /// The stable identifier Android stores against.
  ///
  /// **Never change one of these.** Android keys a channel's settings — the
  /// user's own choices about sound, importance and whether it is on at all — to
  /// this string. A new id is a new channel with default settings, and the old
  /// one lingers in Settings as a row that does nothing.
  final String id;

  /// What the user reads in system settings.
  final String name;

  /// The line beneath it, explaining what turning it off would silence.
  final String description;
}
