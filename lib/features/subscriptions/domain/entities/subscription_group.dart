import 'package:meta/meta.dart';

import 'subscription.dart';

/// The three states a subscription can be in, as far as the list is concerned.
///
/// Ordered as they are declared, which is the order they appear: what needs a
/// decision, then what is running, then what is over.
enum SubscriptionGroup {
  /// Free now, charging soon. First because it is the only one with a deadline.
  trial('Free trials'),

  /// Charging.
  active('Active'),

  /// Paused or finished. Kept, because a cancelled subscription is the record of
  /// a decision — but at the bottom, where history belongs.
  stopped('Stopped');

  const SubscriptionGroup(this.label);

  /// The heading above the group.
  final String label;
}

/// One heading and the subscriptions under it.
@immutable
class SubscriptionSection {
  const SubscriptionSection({required this.group, required this.subscriptions});

  final SubscriptionGroup group;
  final List<Subscription> subscriptions;

  @override
  String toString() =>
      'SubscriptionSection(${group.name}, ${subscriptions.length})';
}

/// Splits [ordered] into sections, keeping the order it arrived in.
///
/// ## Why the list is grouped at all
///
/// It was a flat column, and a stopped subscription sat between two live ones
/// separated from them by nothing but a slightly greyer heading. The reader had
/// to check every row's badge to know which of them were actually costing money
/// — on the screen whose entire job is answering that.
///
/// Grouping also puts trials at the top, which is where the only *deadline* on
/// this screen lives. Everything else here can be dealt with next month.
///
/// **The sort still applies inside a group.** Sections say what kind of thing a
/// row is; the sort says which of them to look at first, and neither is a
/// substitute for the other.
///
/// Empty groups are left out, so a user with three plain subscriptions and no
/// trials gets one section — and, because one section needs no heading to
/// distinguish it from the others, no headings at all.
List<SubscriptionSection> groupSubscriptions(
  List<Subscription> ordered, {
  required DateTime today,
}) {
  final Map<SubscriptionGroup, List<Subscription>> buckets =
      <SubscriptionGroup, List<Subscription>>{};

  for (final Subscription subscription in ordered) {
    final SubscriptionGroup group = switch (subscription) {
      // Stopped is checked first. A paused subscription with a trial date still
      // in the future is stopped, not trialling: nothing is going to charge.
      Subscription(isActive: false) => SubscriptionGroup.stopped,
      _ when subscription.isInTrial(today) => SubscriptionGroup.trial,
      _ => SubscriptionGroup.active,
    };

    buckets.putIfAbsent(group, () => <Subscription>[]).add(subscription);
  }

  return <SubscriptionSection>[
    for (final SubscriptionGroup group in SubscriptionGroup.values)
      if (buckets[group] case final List<Subscription> found)
        SubscriptionSection(
          group: group,
          subscriptions: List<Subscription>.unmodifiable(found),
        ),
  ];
}
