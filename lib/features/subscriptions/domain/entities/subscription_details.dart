import 'package:meta/meta.dart';

/// The half of a subscription that is not a recurring bill.
///
/// ## Why this is so small
///
/// Everything a subscription shares with any other repeating obligation — the
/// name, the amount, the billing frequency, the next billing date — is a
/// `RecurringBill`, and has been since Sprint 18. `public.subscriptions` is a
/// 1:1 extension holding only what is genuinely subscription-specific, and this
/// is its client half.
///
/// The roadmap asked Sprint 48 for a name, an amount, a frequency and a next
/// billing date. All four already existed. Building them again here would have
/// been two tables disagreeing about what Netflix costs.
@immutable
class SubscriptionDetails {
  const SubscriptionDetails({
    required this.recurringBillId,
    required this.provider,
    this.planName,
    this.trialEndsOn,
    this.autoRenews = true,
    this.cancellationUrl,
  });

  /// The template this extends. Also its primary key — one subscription row per
  /// recurring bill, enforced by the key rather than by a constraint bolted on.
  final String recurringBillId;

  /// Who charges for it: 'Netflix', 'Spotify', 'Globe'.
  ///
  /// Required, and distinct from the template's `name` and `payee`. A
  /// subscription named "Family plan" is unidentifiable without it.
  final String provider;

  /// Which plan, where a provider sells more than one. 'Premium', '4 devices'.
  final String? planName;

  /// When the free period ends.
  ///
  /// Its own column rather than something inferred from the start date: a trial
  /// that is about to convert is the thing people actually want warning about,
  /// and Sprint 51 warns about it.
  final DateTime? trialEndsOn;

  /// Whether it renews on its own.
  ///
  /// False is a subscription somebody has already cancelled and is running out
  /// the clock on — still a cost until the date, and not one to be reminded to
  /// cancel again.
  final bool autoRenews;

  /// Where to go to cancel.
  ///
  /// Stored because finding it again is the hard part of cancelling anything.
  final String? cancellationUrl;

  /// The longest a provider or plan name may be, matching the column checks.
  static const int nameMaxLength = 120;

  /// Whether a free period was ever recorded.
  bool get hasTrial => trialEndsOn != null;

  /// Whether the free period is still running on [today].
  ///
  /// The last day counts as trial: a trial ending on the 20th is free *on* the
  /// 20th, which is how every provider words it and how the user will read it.
  /// Compared **date to date**, through [daysOfTrialLeft]. Comparing the two
  /// values directly looked equivalent and was not: `trialEndsOn` is a date at
  /// midnight and [today] usually carries a time, so a trial ending today read
  /// as finished from one second past midnight — on the one day the answer
  /// matters most.
  bool isInTrial(DateTime today) => (daysOfTrialLeft(today) ?? -1) >= 0;

  /// Days of free period left on [today], or null if there is no trial.
  ///
  /// Zero on the last day, and negative once it has passed — a caller that wants
  /// "over" should ask [isInTrial] rather than reading a sign.
  int? daysOfTrialLeft(DateTime today) {
    if (trialEndsOn case final DateTime ends) {
      return DateTime(
        ends.year,
        ends.month,
        ends.day,
      ).difference(DateTime(today.year, today.month, today.day)).inDays;
    }

    return null;
  }

  /// Whether there is somewhere to send the user to cancel.
  bool get hasCancellationLink =>
      cancellationUrl != null && cancellationUrl!.trim().isNotEmpty;

  /// Why this cannot be stored, or null when it can.
  ///
  /// Mirrors the checks in `0006_subscriptions.sql`, so a form can say what is
  /// wrong before the round trip rather than surfacing a Postgres error.
  String? validate() {
    final String trimmedProvider = provider.trim();

    if (trimmedProvider.isEmpty || trimmedProvider.length > nameMaxLength) {
      return 'Say who charges for it, in $nameMaxLength characters or fewer.';
    }

    if (planName case final String plan
        when plan.trim().length > nameMaxLength) {
      return 'The plan name is too long.';
    }

    return null;
  }

  SubscriptionDetails copyWith({
    String? provider,
    String? planName,
    DateTime? trialEndsOn,
    bool? autoRenews,
    String? cancellationUrl,
    bool clearPlanName = false,
    bool clearTrialEndsOn = false,
    bool clearCancellationUrl = false,
  }) => SubscriptionDetails(
    recurringBillId: recurringBillId,
    provider: provider ?? this.provider,
    planName: clearPlanName ? null : (planName ?? this.planName),
    trialEndsOn: clearTrialEndsOn ? null : (trialEndsOn ?? this.trialEndsOn),
    autoRenews: autoRenews ?? this.autoRenews,
    cancellationUrl: clearCancellationUrl
        ? null
        : (cancellationUrl ?? this.cancellationUrl),
  );

  @override
  bool operator ==(Object other) =>
      other is SubscriptionDetails &&
      other.recurringBillId == recurringBillId &&
      other.provider == provider &&
      other.planName == planName &&
      other.trialEndsOn == trialEndsOn &&
      other.autoRenews == autoRenews &&
      other.cancellationUrl == cancellationUrl;

  @override
  int get hashCode => Object.hash(
    recurringBillId,
    provider,
    planName,
    trialEndsOn,
    autoRenews,
    cancellationUrl,
  );

  @override
  String toString() => 'SubscriptionDetails($provider, plan: $planName)';
}
