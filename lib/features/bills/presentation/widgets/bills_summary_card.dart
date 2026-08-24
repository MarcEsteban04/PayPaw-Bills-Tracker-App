import 'package:flutter/material.dart';

import '../../../../core/domain/money.dart';
import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/bill_status.dart';
import '../../domain/entities/bill_with_status.dart';

/// What the whole list adds up to, on one card.
///
/// Modelled on the reference design's balance panel: one figure large enough to
/// read at arm's length, and two smaller ones beneath it in their own tinted
/// pills. The reference shows Total Expense and Total Income; the equivalent
/// question here is not "how much are my bills" but **"how much do I owe, and how
/// much of it is already late"**.
///
/// So the headline is outstanding rather than total, and the two figures under it
/// are overdue and due-soon. A bill that is paid contributes nothing to any of
/// them, which is the point: this card is a measure of what is left to do.
class BillsSummaryCard extends StatelessWidget {
  const BillsSummaryCard({required this.bills, super.key});

  final List<BillWithStatus> bills;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final _Totals totals = _Totals.of(bills);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      borderRadius: AppRadii.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Total outstanding',
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            totals.outstanding.format(),
            style: textTheme.displaySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              // Tabular figures would be better here, but the app's typeface does
              // not ship them; the size is what carries this line.
              height: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(switch (totals.unpaidCount) {
            0 => 'Nothing outstanding',
            1 => 'across 1 bill',
            final int count => 'across $count bills',
          }, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: _Figure(
                  label: 'Overdue',
                  amount: totals.overdue,
                  count: totals.overdueCount,
                  tone: AppStatusTone.overdue,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _Figure(
                  label: 'Due soon',
                  amount: totals.dueSoon,
                  count: totals.dueSoonCount,
                  tone: AppStatusTone.dueSoon,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One of the two figures under the headline.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.amount,
    required this.count,
    required this.tone,
  });

  final String label;
  final Money amount;
  final int count;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Tinted only when there is something to report. A red panel showing ₱0.00
    // is an alarm about nothing, and it teaches the reader to ignore the colour.
    final bool isActive = count > 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isActive ? colors.statusTint(tone) : colors.surfaceMuted,
        borderRadius: AppRadii.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: isActive
                    ? colors.statusText(tone)
                    : colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              amount.format(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                color: isActive ? colors.statusText(tone) : colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sums, worked out once.
class _Totals {
  const _Totals({
    required this.outstanding,
    required this.overdue,
    required this.dueSoon,
    required this.unpaidCount,
    required this.overdueCount,
    required this.dueSoonCount,
  });

  factory _Totals.of(List<BillWithStatus> bills) {
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
    int unpaidCount = 0;
    int overdueCount = 0;
    int dueSoonCount = 0;

    for (final BillWithStatus bill in bills) {
      if (!(bill.status?.isOutstanding ?? false)) {
        continue;
      }

      outstanding += bill.outstanding;
      unpaidCount++;

      switch (bill.status) {
        case BillStatus.overdue:
          overdue += bill.outstanding;
          overdueCount++;
        case BillStatus.dueSoon:
          dueSoon += bill.outstanding;
          dueSoonCount++;
        case _:
          break;
      }
    }

    return _Totals(
      outstanding: outstanding,
      overdue: overdue,
      dueSoon: dueSoon,
      unpaidCount: unpaidCount,
      overdueCount: overdueCount,
      dueSoonCount: dueSoonCount,
    );
  }

  final Money outstanding;
  final Money overdue;
  final Money dueSoon;
  final int unpaidCount;
  final int overdueCount;
  final int dueSoonCount;
}
