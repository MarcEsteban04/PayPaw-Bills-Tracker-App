import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/debt_summary.dart';
import '../../domain/entities/debt_with_status.dart';
import '../controllers/debt_providers.dart';

/// Where the user stands on utang, on the dashboard.
///
/// ## Why this is on the dashboard and not a screen of its own
///
/// The roadmap calls Sprint 55 a "Debt Dashboard". A separate one would have
/// been a fifth destination showing four figures, reached from a row that
/// already has four tiles — and the question it answers, *is any of this urgent
/// today*, is the exact question the dashboard exists for. Two dashboards is one
/// dashboard and a screen nobody opens.
///
/// The Utang screen keeps its own per-direction total, which is a different
/// thing: that one is context for the list under it, this one is a summary you
/// see without going looking.
///
/// ## Both sides, never netted
///
/// See [DebtSummary]: subtracting what you are owed from what you owe treats a
/// receivable as cash, and half of informal lending comes back late, in kind, or
/// not at all. The two figures sit beside each other and the reader does
/// whichever subtraction they actually trust.
///
/// Absent entirely when there is no open utang. A card reading ₱0.00 twice is a
/// card teaching somebody to ignore that part of the screen.
class DebtSummaryCard extends ConsumerWidget {
  const DebtSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DebtSummary summary = ref.watch(debtSummaryProvider);

    if (!summary.hasAnything) {
      return const SizedBox.shrink();
    }

    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: () => context.pushNamed(AppRoutes.debts.routeName),
      padding: const EdgeInsets.all(AppSpacing.xl),
      borderRadius: AppRadii.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Utang',
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Only the sides that have something on them.
          //
          // Showing both always meant a card reading "OWED TO YOU ₱0.00 · 0
          // people" for everybody who has never lent a peso — which is the same
          // fault as a ₱0.00 card, one column in. It is not reassuring the way
          // "₱0.00 overdue" is on the bills card; it is just absence taking up
          // half the width.
          //
          // The other direction is still one tap away on the screen this card
          // opens, where the switch names both sides whether or not they are
          // empty.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final (int index, _Side side) in _sides(
                summary,
              ).indexed) ...<Widget>[
                if (index > 0) const SizedBox(width: AppSpacing.md),
                Expanded(child: side),
              ],
            ],
          ),

          if (summary.hasOverdue) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _OverdueNote(summary: summary),
          ],

          if (summary.soonest case final DebtWithStatus next
              when !next.isOverdue) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _NextNote(next: next),
          ],

          // Said out loud, because a card built from "overdue" and "upcoming"
          // would otherwise omit these entirely — they are in the figures above
          // and in neither line below.
          if (summary.undatedCount > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              summary.undatedCount == 1
                  ? '1 with no date agreed'
                  : '${summary.undatedCount} with no date agreed',
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

/// The halves of the ledger that have anything on them.
///
/// What you owe leads when both are present: money going out is the half with a
/// consequence, and it gets the larger type. Alone, it is the only figure on the
/// card and needs no comparison.
List<_Side> _sides(DebtSummary summary) => <_Side>[
  if (summary.owedCount > 0)
    _Side(
      label: 'YOU OWE',
      amount: summary.owed.format(),
      count: summary.owedCount,
      isEmphasised: true,
    ),
  if (summary.receivableCount > 0)
    _Side(
      label: 'OWED TO YOU',
      amount: summary.receivable.format(),
      count: summary.receivableCount,
      // Emphasised when it is the only thing here, quieter when it sits beside
      // what is going out. Money coming in is good news and does not need to
      // shout over a debt.
      isEmphasised: summary.owedCount == 0,
    ),
];

/// One half of the ledger.
class _Side extends StatelessWidget {
  const _Side({
    required this.label,
    required this.amount,
    required this.count,
    required this.isEmphasised,
  });

  final String label;
  final String amount;
  final int count;
  final bool isEmphasised;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(
            color: colors.textTertiary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          amount,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (isEmphasised ? textTheme.headlineSmall : textTheme.titleLarge)
              ?.copyWith(
                color: isEmphasised ? colors.textPrimary : colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          count == 1 ? '1 person' : '$count people',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
        ),
      ],
    );
  }
}

/// What is late, in whichever direction it is late in.
class _OverdueNote extends StatelessWidget {
  const _OverdueNote({required this.summary});

  final DebtSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.overdueTint,
        borderRadius: AppRadii.chip,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: colors.overdueText,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _message(),
              style: textTheme.bodySmall?.copyWith(
                color: colors.overdueText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Names which side is late, because the action differs.
  ///
  /// Utang you owe past its date is something to go and pay. Utang owed to you
  /// past its date is somebody to go and ask. One sentence covering both would
  /// tell the reader neither.
  String _message() {
    final bool mine = summary.overdueOwed.minorUnits > 0;
    final bool theirs = summary.overdueReceivable.minorUnits > 0;

    if (mine && theirs) {
      return '${summary.overdueOwed.format()} of yours and '
          '${summary.overdueReceivable.format()} of theirs is past its date';
    }

    if (mine) {
      return '${summary.overdueOwed.format()} is past the date you agreed';
    }

    return '${summary.overdueReceivable.format()} was due back by now';
  }
}

/// The next agreed date.
class _NextNote extends StatelessWidget {
  const _NextNote({required this.next});

  final DebtWithStatus next;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        Icon(Icons.event_outlined, size: 16, color: colors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            // Names the person, not just the date. "Next on Sep 12" makes the
            // reader open the screen to find out whose; the name is the whole
            // reason the line is worth a row of the card.
            next.direction.isOutgoing
                ? 'Next: ${next.counterpartyName} on '
                      '${DateFormat.MMMd().format(next.debt.dueOn!)}'
                : '${next.counterpartyName} owes you back by '
                      '${DateFormat.MMMd().format(next.debt.dueOn!)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
