import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_spend.dart';

/// What the subscriptions cost, above the list of them.
///
/// ## Why the screen needed a head at all
///
/// It was a list and nothing else, which answered "what am I signed up for" and
/// left the question people actually open it with — **"how much is all this"** —
/// to be worked out by reading twelve rows and doing arithmetic on mixed units.
///
/// The monthly figure leads because it is the one people budget in. The annual
/// one sits under it because it is the one that changes minds: ₱549 a month and
/// ₱6,588 a year are the same fact and only one of them sounds like a decision.
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
            style: textTheme.displaySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            // The count says what the figure is *of*. Without it a reader who
            // has paused three subscriptions cannot tell whether they are in
            // the number or not — and they are not.
            '${spend.perYear.format()} a year · '
            '${spend.activeCount} ${spend.activeCount == 1 ? 'subscription' : 'subscriptions'}',
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),

          if (spend.hasPendingTrials) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _TrialNote(spend: spend),
          ],

          if (spend.costliest case final Subscription dearest
              when spend.activeCount + spend.trialCount > 1) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: AppSpacing.lg),
            _Dearest(subscription: dearest),
          ],
        ],
      ),
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

/// The single biggest one.
///
/// "What is the expensive one" is the next question after "how much", and it is
/// the question the roadmap's *most expensive subscriptions* is really asking.
/// One name here rather than a ranked block of three, because the full ranking
/// is the list below under its Cost order — printing the top three twice on one
/// screen would be a table of contents for a page you can already see.
class _Dearest extends StatelessWidget {
  const _Dearest({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        Icon(Icons.trending_up_rounded, size: 18, color: colors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Dearest is ${subscription.details.provider}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          // The normalised figure, not the row's own. Comparing a yearly plan
          // with a monthly one on their face values is what makes the wrong one
          // look dearest.
          '${SubscriptionSpend.monthlyCostOf(subscription).format()}/mo',
          style: textTheme.bodySmall?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
