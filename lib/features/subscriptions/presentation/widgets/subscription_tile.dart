import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/presentation/widgets/app_status_chip.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/subscription.dart';

/// One subscription in the list.
///
/// ## What a row has to answer
///
/// Not "what is this" — the provider says that. The question somebody opens this
/// screen with is **"should I still be paying for this"**, so the row leads with
/// the provider, then what it costs and when it next charges, and calls out the
/// two states that change the answer: a trial about to convert, and a
/// subscription that has been stopped.
class SubscriptionTile extends StatelessWidget {
  const SubscriptionTile({
    required this.subscription,
    required this.today,
    required this.onTap,
    super.key,
  });

  final Subscription subscription;

  /// Today in the user's own zone, so a trial countdown cannot disagree with the
  /// dates on the screen behind it.
  final DateTime today;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final bool isPaused = !subscription.isActive;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  subscription.providerLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    // Dimmed when stopped. The row stays — a cancelled
                    // subscription is the record of a decision — but it should
                    // not read as something still costing money.
                    color: isPaused ? colors.textSecondary : colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  _caption(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (_badge() case final _Badge badge) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  AppStatusChip(label: badge.label, tone: badge.tone),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            subscription.amount.format(),
            style: textTheme.titleSmall?.copyWith(
              color: isPaused ? colors.textSecondary : colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// The name and when it next charges.
  ///
  /// The name is here rather than in the heading because the provider is what
  /// identifies a subscription — "Family plan" on its own tells nobody what it
  /// is a plan for. When the two are the same word, saying it twice would be
  /// worse than saying it once.
  String _caption() {
    final String when = subscription.isActive
        ? 'Next ${DateFormat.MMMd().format(subscription.nextBillingOn)}'
        : 'Stopped';

    if (subscription.name.trim() == subscription.details.provider.trim()) {
      return when;
    }

    return '${subscription.name} · $when';
  }

  /// The one state worth interrupting the row for, or none.
  ///
  /// At most one. A row carrying three chips is a row nobody reads, and these
  /// are in the order they matter: a trial converts whether or not anybody
  /// notices, and a subscription that will not renew is already handled.
  _Badge? _badge() {
    if (subscription.isInTrial(today)) {
      final int? left = subscription.details.daysOfTrialLeft(today);

      return _Badge(switch (left) {
        null => 'TRIAL',
        0 => 'TRIAL ENDS TODAY',
        1 => 'TRIAL ENDS TOMORROW',
        final int days => 'TRIAL · $days DAYS',
      }, AppStatusTone.dueSoon);
    }

    if (!subscription.isActive) {
      return const _Badge('STOPPED', AppStatusTone.neutral);
    }

    if (!subscription.details.autoRenews) {
      return const _Badge('WILL NOT RENEW', AppStatusTone.info);
    }

    return null;
  }
}

class _Badge {
  const _Badge(this.label, this.tone);

  final String label;
  final AppStatusTone tone;
}
