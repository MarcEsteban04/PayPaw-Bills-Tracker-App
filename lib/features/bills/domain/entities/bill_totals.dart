import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'bill_status.dart';
import 'bill_with_status.dart';

/// What a set of bills adds up to.
///
/// Extracted from the bills summary card when the dashboard needed the same
/// figures. Two screens each summing their own way is two definitions of "total
/// outstanding", and the day they disagree the user is looking at one of them
/// believing the other.
///
/// In domain rather than beside a widget: these are arithmetic on money, they are
/// worth testing without a screen, and nothing here imports Flutter.
@immutable
class BillTotals {
  const BillTotals({
    required this.outstanding,
    required this.overdue,
    required this.dueSoon,
    required this.billed,
    required this.settled,
    required this.unpaidCount,
    required this.overdueCount,
    required this.dueSoonCount,
  });

  factory BillTotals.of(List<BillWithStatus> bills) {
    // Currency comes from the bills themselves rather than a constant: adding
    // Money of different currencies throws, and an empty list has no currency at
    // all, so the first bill decides and PHP is the fallback.
    //
    // Mixed currencies would still throw. That is the right failure for now —
    // silently adding dollars to pesos would be a wrong total presented
    // confidently — and a per-currency breakdown belongs with the analytics in
    // Phase 13.
    final String currency = bills.isEmpty
        ? 'PHP'
        : bills.first.outstanding.currency;

    Money outstanding = Money(minorUnits: 0, currency: currency);
    Money overdue = Money(minorUnits: 0, currency: currency);
    Money dueSoon = Money(minorUnits: 0, currency: currency);
    Money billed = Money(minorUnits: 0, currency: currency);
    Money settled = Money(minorUnits: 0, currency: currency);
    int unpaidCount = 0;
    int overdueCount = 0;
    int dueSoonCount = 0;

    for (final BillWithStatus bill in bills) {
      // Archived bills are in neither the progress nor the totals. The user has
      // put them away, and counting them would make the denominator include work
      // nobody intends to do.
      if (bill.bill.isArchived) {
        continue;
      }

      // Progress counts settled bills, unlike every other figure here — clearing
      // one is the progress.
      billed += bill.bill.amount;
      settled += bill.paid;

      if (!(bill.status?.isOutstanding ?? false)) {
        continue;
      }

      outstanding += bill.outstanding;
      unpaidCount++;

      switch (bill.status) {
        case BillStatus.overdue:
          overdue += bill.outstanding;
          overdueCount++;
        // Due-today counts into the due-soon figure. "Due soon" already reads as
        // including today, and the lists that need to separate them have their
        // own headings.
        case BillStatus.dueSoon:
        case BillStatus.dueToday:
          dueSoon += bill.outstanding;
          dueSoonCount++;
        case _:
          break;
      }
    }

    return BillTotals(
      outstanding: outstanding,
      overdue: overdue,
      dueSoon: dueSoon,
      billed: billed,
      settled: settled,
      unpaidCount: unpaidCount,
      overdueCount: overdueCount,
      dueSoonCount: dueSoonCount,
    );
  }

  final Money outstanding;
  final Money overdue;
  final Money dueSoon;

  /// Everything not archived, at face value.
  final Money billed;

  /// How much of [billed] has been paid.
  final Money settled;

  final int unpaidCount;
  final int overdueCount;
  final int dueSoonCount;

  /// Whether there is a denominator worth drawing a bar for.
  bool get hasProgress => billed.minorUnits > 0;

  double get settledFraction =>
      hasProgress ? settled.minorUnits / billed.minorUnits : 0;

  /// Whether anything needs attention today rather than eventually.
  bool get needsAttention => overdueCount > 0 || dueSoonCount > 0;
}
