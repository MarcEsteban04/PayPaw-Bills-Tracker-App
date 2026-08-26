import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_spend.dart';
import 'subscription_share_bar.dart';

/// What the subscriptions cost, above the list of them.
///
/// ## Why the screen needed a head at all
///
/// It was a list and nothing else, which answered "what am I signed up for" and
/// left the question people actually open it with — **"how much is all this"** —
/// to be worked out by reading twelve rows and doing arithmetic on mixed units.
///
/// The monthly figure leads because it is the one people budget in. The annual
/// one sits beside it because it is the one that changes minds: ₱549 a month and
/// ₱6,588 a year are the same fact and only one of them sounds like a decision.
///
/// ## And then it shows where the money goes
///
/// The first version of this card said "Dearest is Adobe" and left the reader to
/// divide. [SubscriptionShareBar] draws the split instead, so "one service is
/// most of this" is something you see rather than something you work out.
class SubscriptionSpendCard extends StatelessWidget {
  const SubscriptionSpendCard({required this.spend, super.key});

  final SubscriptionSpend spend;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      borderRadius: AppRadii.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              // Both halves flex, in a fixed ratio. A right-hand column laid out
              // at its natural width overflows a 320dp phone at text scale 2 —
              // the two figures simply do not fit side by side there — and a
              // loose `Flexible` would fix that at the cost of unpinning the
              // aside from the card's right edge at every ordinary size.
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'EVERY MONTH',
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.textTertiary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      spend.perMonth.format(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.displaySmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // The year, on its own and to the side rather than buried in a
              // sentence under the figure. It is the number that changes minds,
              // and it was previously the smallest thing on the card.
              Expanded(
                flex: 2,
                child: _Aside(
                  label: 'A YEAR',
                  value: spend.perYear.format(),
                  caption:
                      '${spend.activeCount} '
                      '${spend.activeCount == 1 ? 'service' : 'services'}',
                ),
              ),
            ],
          ),

          if (spend.ranked.length > 1) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            SubscriptionShareBar(spend: spend),
            if (spend.costliest case final Subscription dearest) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _DearestLine(dearest: dearest, spend: spend),
            ],
          ],

          if (spend.hasPendingTrials) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _TrialNote(spend: spend),
          ],
        ],
      ),
    );
  }
}

/// A secondary figure, right-aligned beside the headline.
class _Aside extends StatelessWidget {
  const _Aside({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colors.textTertiary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          caption,
          style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
        ),
      ],
    );
  }
}

/// Which slice of the bar is the big one, in words.
///
/// The bar shows the shape and this names it. Neither is enough alone: a bar
/// with no labels is a decoration, and a label with no bar is the sentence this
/// card used to carry, which made the reader do the division.
class _DearestLine extends StatelessWidget {
  const _DearestLine({required this.dearest, required this.spend});

  final Subscription dearest;
  final SubscriptionSpend spend;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final int total = spend.ranked.fold<int>(
      0,
      (int sum, Subscription each) =>
          sum + SubscriptionSpend.monthlyCostOf(each).minorUnits,
    );

    if (total <= 0) {
      return const SizedBox.shrink();
    }

    final int percent =
        (SubscriptionSpend.monthlyCostOf(dearest).minorUnits * 100 / total)
            .round();

    return Text(
      '${dearest.details.provider} is $percent% of it',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
    );
  }
}

/// What the total will become when the free periods end.
///
/// Its own line rather than folded into the figure above. A subscription inside
/// a trial charges nothing today, so counting it would overstate what is leaving
/// the account — and saying nothing would let the total jump the week it
/// converts with no explanation on screen.
class _TrialNote extends StatelessWidget {
  const _TrialNote({required this.spend});

  final SubscriptionSpend spend;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.dueSoonTint,
        borderRadius: AppRadii.chip,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.hourglass_bottom_rounded,
            size: 18,
            color: colors.dueSoonText,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '+${spend.whenTrialsConvert.format()} a month when '
              '${spend.trialCount == 1 ? 'this trial ends' : 'these ${spend.trialCount} trials end'}',
              style: textTheme.bodySmall?.copyWith(
                color: colors.dueSoonText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
