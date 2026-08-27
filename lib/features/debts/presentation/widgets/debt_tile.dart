import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/presentation/widgets/app_status_chip.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../subscriptions/presentation/widgets/subscription_mark.dart';
import '../../domain/entities/debt_with_status.dart';

/// One debt in the list.
///
/// ## What a row has to answer
///
/// **"How much of this is left."** Not what it started at — that is history the
/// moment the first repayment lands — which is why the outstanding figure leads
/// and the principal sits beneath it as context.
///
/// The progress bar is the instalment story: a debt paid in chunks *is* a debt
/// with several payments against it in this schema, and the bar is what makes
/// three of five payments legible without counting rows.
class DebtTile extends StatelessWidget {
  const DebtTile({required this.item, required this.onTap, super.key});

  final DebtWithStatus item;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final bool isDone = item.isSettled;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              // The counterparty's initials, on the same generated mark a
              // subscription uses. A person is exactly the case that widget was
              // built for — a name with no icon behind it — and inventing a
              // second monogram treatment would make the app look assembled
              // rather than designed.
              SubscriptionMark(
                provider: item.counterpartyName,
                isMuted: isDone,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.counterpartyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        color: isDone
                            ? colors.textSecondary
                            : colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _caption(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: item.isOverdue
                            ? colors.overdueText
                            : colors.textSecondary,
                        fontWeight: item.isOverdue
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      // What is left, not what it was. Once a repayment lands,
                      // the original figure is history and the remainder is the
                      // thing being decided about.
                      item.outstanding.format(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        color: isDone
                            ? colors.textSecondary
                            : colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.isPartiallyRepaid) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'of ${item.principal.format()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Only where something has been repaid and something is left. On an
          // untouched debt the bar would be empty and on a finished one full,
          // which are two ways of saying what the figures already said.
          if (item.isPartiallyRepaid && !isDone) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _ProgressBar(fraction: item.progress),
          ],

          if (_badge(colors) case final _Badge badge) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: AppStatusChip(label: badge.label, tone: badge.tone),
            ),
          ],
        ],
      ),
    );
  }

  /// How many payments, and when it is due — the two things that change what to
  /// do next.
  String _caption() {
    final String instalments = switch (item.paymentCount) {
      0 => 'Nothing repaid yet',
      1 => '1 payment',
      final int count => '$count payments',
    };

    if (item.isSettled) {
      return '$instalments · Settled';
    }

    // No agreed date is a fact worth printing, not a blank. It is the difference
    // between a debt somebody promised to repay and one they did not.
    if (item.debt.dueOn case final DateTime due) {
      return '$instalments · ${item.isOverdue ? 'Was due' : 'Due'} '
          '${DateFormat.MMMd().format(due)}';
    }

    return '$instalments · No date agreed';
  }

  _Badge? _badge(AppPalette colors) {
    if (item.isSettled) {
      return const _Badge('SETTLED', AppStatusTone.neutral);
    }

    if (item.isOverdue) {
      return const _Badge('OVERDUE', AppStatusTone.overdue);
    }

    // The arithmetic says it is square but the user has not closed it. Worth
    // saying, because it is the one row where the obvious next action is a tap
    // rather than a payment.
    if (item.isFullyRepaid) {
      return const _Badge('FULLY REPAID', AppStatusTone.paid);
    }

    return null;
  }
}

/// How much of the debt is done.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return ClipRRect(
      borderRadius: AppRadii.chip,
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 6,
        backgroundColor: colors.surfaceMuted,
        valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
      ),
    );
  }
}

class _Badge {
  const _Badge(this.label, this.tone);

  final String label;
  final AppStatusTone tone;
}
