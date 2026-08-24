import 'package:flutter/material.dart';

import '../../../../core/domain/money.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/bill_totals.dart';
import '../../domain/entities/bill_with_status.dart';

/// What the whole list adds up to.
///
/// ## Why this one is dark
///
/// It was a white card among white cards, which made the most important figure on
/// the screen look like one more row. The reference design's balance panel is the
/// hero of its screen; this earns that by being a different *surface* rather than
/// a bigger number on the same one.
///
/// Dark rather than green: the navigation bar is already `navSurface`, so the two
/// dark shapes bracket the screen and the green stays reserved for things you can
/// press. It is a card on a light canvas, not a theme flip — the distinction the
/// welcome screen got wrong once already.
///
/// ## What it says
///
/// Outstanding, not total: this is a measure of work left, so a partly paid bill
/// contributes only its remainder and a settled one contributes nothing.
///
/// Then progress — what has been settled against what was billed — because a
/// number with no denominator cannot be read as good or bad. ₱1,500 outstanding
/// means one thing when nothing has been paid and another when it is the last
/// tenth of the month.
///
/// Then overdue and due-soon, which is the reference's two-figure split applied to
/// the question this app actually answers.
class BillsSummaryCard extends StatelessWidget {
  const BillsSummaryCard({required this.bills, super.key});

  final List<BillWithStatus> bills;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final BillTotals totals = BillTotals.of(bills);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.navSurface,
        borderRadius: AppRadii.panel,
        boxShadow: colors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'TOTAL OUTSTANDING',
                    style: textTheme.labelSmall?.copyWith(
                      // Letter-spaced small caps rather than sentence case: on a
                      // dark surface a quiet label needs the extra structure to
                      // stay legible at this weight.
                      color: colors.textOnDark.withValues(alpha: 0.55),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (totals.unpaidCount > 0)
                  _CountBadge(count: totals.unpaidCount),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              totals.outstanding.format(),
              style: textTheme.displaySmall?.copyWith(
                color: colors.textOnDark,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (totals.hasProgress) ...<Widget>[
              _ProgressBar(fraction: totals.settledFraction),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${totals.settled.format()} of ${totals.billed.format()} settled',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textOnDark.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ] else ...<Widget>[
              Text(
                'Nothing outstanding',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textOnDark.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            Row(
              children: <Widget>[
                Expanded(
                  child: _Figure(
                    label: 'Overdue',
                    amount: totals.overdue,
                    count: totals.overdueCount,
                    accent: colors.overdue,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _Figure(
                    label: 'Due soon',
                    amount: totals.dueSoon,
                    count: totals.dueSoonCount,
                    accent: colors.dueSoon,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// How many bills are still owing, as a pill beside the label.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.navItemSunken,
        borderRadius: AppRadii.round,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          switch (count) {
            1 => '1 bill',
            _ => '$count bills',
          },
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.textOnDark.withValues(alpha: 0.75),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// How much of what was billed has been settled.
///
/// A number on its own cannot be read as good or bad; this is the denominator.
/// Lime rather than green — on `navSurface` the brand green goes muddy, and lime
/// is the palette's own answer for an accent on this surface, as the navigation
/// bar's selected pill already shows.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  /// 0 to 1.
  final double fraction;

  static const double _height = 8;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Semantics(
      // Announced as a value, because a bar is invisible to a screen reader and
      // the sentence underneath it is the only other place this appears.
      label: 'Settled',
      value: '${(fraction * 100).round()} percent',
      child: ClipRRect(
        borderRadius: AppRadii.round,
        child: SizedBox(
          height: _height,
          child: Stack(
            children: <Widget>[
              // A wash of the foreground, not `navItemSunken`. The sunken colour
              // sits only a few points off `navSurface`, so at 0% the bar
              // vanished and left an unexplained gap under the headline. An
              // invisible progress bar is worse than none.
              ColoredBox(color: colors.textOnDark.withValues(alpha: 0.22)),
              FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: colors.navActivePill),
                ),
              ),
            ],
          ),
        ),
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
    required this.accent,
  });

  final String label;
  final Money amount;
  final int count;

  /// The status colour, used for the dot and the figure when there is something
  /// to report.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Coloured only when there is something to report. A red figure reading ₱0.00
    // is an alarm about nothing, and it teaches the reader to ignore the colour
    // on the day it means something.
    final bool isActive = count > 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.navItemSunken,
        borderRadius: AppRadii.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                // A dot rather than a tinted panel. On a dark surface a wash of
                // red reads as a warning about the whole card; a dot marks the
                // one figure it belongs to.
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? accent
                        : colors.textOnDark.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.textOnDark.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              amount.format(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                color: isActive
                    ? accent
                    : colors.textOnDark.withValues(alpha: 0.5),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
