import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import '../../../recurring/domain/entities/new_recurring_bill.dart';
import '../../../recurring/domain/entities/recurrence.dart';
import '../../../recurring/domain/entities/recurring_bill.dart';
import 'subscription_details.dart';

/// A subscription about to be created.
///
/// Carries both halves because creating one writes two rows, and the caller
/// should describe the thing once rather than assembling a template and an
/// extension and hoping they match.
///
/// **No owner and no id.** Both come from the repository — the session supplies
/// one and the database the other, so no call site can pass the wrong one.
@immutable
class NewSubscription {
  const NewSubscription({
    required this.name,
    required this.amount,
    required this.recurrence,
    required this.provider,
    this.planName,
    this.categoryId,
    this.trialEndsOn,
    this.autoRenews = true,
    this.cancellationUrl,
  });

  final String name;
  final Money amount;
  final Recurrence recurrence;
  final String provider;
  final String? planName;
  final String? categoryId;
  final DateTime? trialEndsOn;
  final bool autoRenews;
  final String? cancellationUrl;

  /// The template half, ready for the recurring repository.
  ///
  /// `kind` is fixed here rather than accepted: a draft of this type is a
  /// subscription by construction, and letting a caller pass `bill` would create
  /// a template with an extension row that nothing would ever look for.
  ///
  /// The **provider** is the payee. It is who the money goes to, which is
  /// exactly what that column means — and it keeps a generated bill saying
  /// "Netflix" on the bills list without the list knowing subscriptions exist.
  NewRecurringBill get template => NewRecurringBill(
    name: name,
    amount: amount,
    recurrence: recurrence,
    kind: RecurringBillKind.subscription,
    categoryId: categoryId,
    payee: provider,
  );

  /// The extension half, once the template has an id.
  SubscriptionDetails detailsFor(String recurringBillId) => SubscriptionDetails(
    recurringBillId: recurringBillId,
    provider: provider,
    planName: planName,
    trialEndsOn: trialEndsOn,
    autoRenews: autoRenews,
    cancellationUrl: cancellationUrl,
  );

  /// Why this cannot be stored, or null when it can.
  ///
  /// Both halves, in the order a form shows them, so the first complaint is
  /// about the first field that is wrong rather than whichever table happened to
  /// be checked first.
  String? validate() => template.validate() ?? detailsFor('unsaved').validate();
}
