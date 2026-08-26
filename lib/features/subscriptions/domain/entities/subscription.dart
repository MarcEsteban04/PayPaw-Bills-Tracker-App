import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import '../../../recurring/domain/entities/recurrence.dart';
import '../../../recurring/domain/entities/recurring_bill.dart';
import 'subscription_details.dart';

/// A subscription: a recurring bill, plus what makes it a subscription.
///
/// **Composes** rather than inherits or flattens, the same way `BillWithStatus`
/// composes a `Bill`. `subscription.template.amount` is a fact about the
/// schedule and `subscription.details.provider` is a fact about the service, and
/// keeping the line visible is what stops a later `copyWith` writing one through
/// the other.
///
/// The forwarding getters below are the exception, and they earn it: `name`,
/// `amount` and `nextBillingOn` are read constantly and
/// `subscription.template.nextDueOn` at every call site would bury the thing
/// being said.
@immutable
class Subscription {
  const Subscription({required this.template, required this.details});

  /// The schedule: name, amount, frequency, next date, whether it is paused.
  final RecurringBill template;

  /// The service: provider, plan, trial, auto-renew, where to cancel.
  final SubscriptionDetails details;

  String get id => template.id;
  String get name => template.name;
  Money get amount => template.amount;
  Recurrence get recurrence => template.recurrence;

  /// When it charges next.
  ///
  /// The template's bookmark under a name that means something here. To the
  /// schedule it is "the next occurrence to generate"; to somebody looking at
  /// their subscriptions it is the day money leaves.
  DateTime get nextBillingOn => template.nextDueOn;

  /// Whether it is still charging.
  ///
  /// Paused and finished templates are not. A subscription somebody stopped is
  /// history, and counting it as a commitment would inflate the figure they
  /// budget against — the same rule `RecurringCommitment` applies.
  bool get isActive => template.isActive && !template.isFinished;

  /// Whether the free period is still running on [today].
  bool isInTrial(DateTime today) => details.isInTrial(today);

  /// Whether this will renew without anybody doing anything.
  ///
  /// Both halves have to agree: a template that is paused does not renew
  /// whatever the service's own setting says.
  bool get willRenew => isActive && details.autoRenews;

  /// The service and its plan, as one line. 'Netflix · Premium'.
  ///
  /// Here rather than in a widget because the list and the detail screen will
  /// both want it and must not word it differently.
  String get providerLine {
    if (details.planName case final String plan when plan.trim().isNotEmpty) {
      return '${details.provider} · ${plan.trim()}';
    }

    return details.provider;
  }

  @override
  bool operator ==(Object other) =>
      other is Subscription &&
      other.template == template &&
      other.details == details;

  @override
  int get hashCode => Object.hash(template, details);

  @override
  String toString() => 'Subscription($name, ${details.provider})';
}
