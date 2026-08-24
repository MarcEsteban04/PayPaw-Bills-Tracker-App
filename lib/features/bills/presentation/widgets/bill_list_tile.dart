import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/controllers/category_providers.dart';
import '../../../categories/presentation/widgets/category_icon.dart';
import '../../domain/entities/bill_status.dart';
import '../../domain/entities/bill_with_status.dart';

/// One bill in a list.
///
/// Shows what decides whether the reader needs to act: what it is, how much is
/// left, and when. The amount is the **outstanding** figure rather than the bill's
/// total, because a bill with ₱2,000 paid of ₱2,450 is a ₱450 problem, and the
/// total would overstate what is owed on every partially paid row.
///
/// ## Why most rows carry no badge
///
/// Every row used to end in a status chip. Twelve rows of chips is twelve pieces
/// of furniture and no information: "Upcoming" on a bill due in three weeks says
/// nothing the line above it has not already said, and a badge that appears
/// everywhere stops being read anywhere.
///
/// So a badge appears only where the status is not already obvious from the date:
/// overdue and due-soon, which are urgent, and part-paid, which the date cannot
/// convey at all. Everything else is left to the due line — and because those
/// rows are quiet, the ones that are not stand out without needing to shout.
///
/// A left rail carries the same signal in colour for the two urgent states. Two
/// cues rather than one, because colour alone is not information for everyone.
class BillListTile extends ConsumerWidget {
  const BillListTile({required this.item, required this.onTap, super.key});

  final BillWithStatus item;
  final VoidCallback onTap;

  /// Width of the coloured edge on an urgent row.
  static const double _railWidth = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Categories are already loaded for the picker; a row with no category, or
    // one whose category has since been deleted, simply shows no icon.
    final Category? category = switch (ref.watch(categoriesProvider)) {
      AsyncData<List<Category>>(value: final List<Category> all) =>
        all.where((Category c) => c.id == item.bill.categoryId).firstOrNull,
      _ => null,
    };

    final Color? rail = switch (item.status) {
      BillStatus.overdue => colors.overdue,
      BillStatus.dueSoon => colors.dueSoon,
      _ => null,
    };

    return AppCard(
      onTap: onTap,
      // Zero, so the rail can reach the card's edges. The inner padding is
      // supplied below instead.
      padding: EdgeInsets.zero,
      child: Row(
        children: <Widget>[
          // The rail occupies the same width whether or not it is coloured, so a
          // quiet row and an urgent one align down the list.
          Container(
            width: _railWidth,
            height: 72,
            decoration: BoxDecoration(
              color: rail ?? Colors.transparent,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppRadii.md),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                children: <Widget>[
                  if (category case final Category value) ...<Widget>[
                    CategoryIcon(category: value, size: 44),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.bill.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          _due(item),
                          style: textTheme.bodySmall?.copyWith(
                            color: switch (item.status) {
                              BillStatus.overdue => colors.overdueText,
                              BillStatus.dueSoon => colors.dueSoonText,
                              _ => colors.textSecondary,
                            },
                            fontWeight: item.status?.needsAttention ?? false
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        item.outstanding.format(),
                        style: textTheme.titleMedium?.copyWith(
                          color: item.status == BillStatus.paid
                              // A settled amount is history, not a demand.
                              ? colors.textTertiary
                              : colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_badge(item.status)
                          case final String label) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          label,
                          style: textTheme.labelSmall?.copyWith(
                            color: switch (item.status) {
                              BillStatus.overdue => colors.overdueText,
                              BillStatus.dueSoon => colors.dueSoonText,
                              _ => colors.infoText,
                            },
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// How soon, in words, counted against the row's own `today` — never the device
  /// clock. See [BillWithStatus.today].
  static String _due(BillWithStatus item) {
    if (item.status == BillStatus.paid) {
      return 'Settled';
    }

    return switch (item.daysUntilDue) {
      0 => 'Due today',
      1 => 'Due tomorrow',
      final int days when days < 0 => '${-days} days overdue',
      final int days => 'Due in $days days',
    };
  }

  /// The badge, or null where the due line already says it.
  ///
  /// Overdue and due-soon are urgent enough to repeat. Part-paid is the one the
  /// date cannot express at all: a bill can be half settled and not due for weeks.
  static String? _badge(BillStatus? status) => switch (status) {
    BillStatus.overdue => 'OVERDUE',
    BillStatus.dueSoon => 'DUE SOON',
    BillStatus.partiallyPaid => 'PART PAID',
    _ => null,
  };
}
