import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/presentation/widgets/app_status_chip.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/controllers/category_providers.dart';
import '../../../categories/presentation/widgets/category_icon.dart';
import '../../domain/entities/bill_status.dart';
import '../../domain/entities/bill_with_status.dart';

/// One bill in a list.
///
/// Shows the four things that decide whether the reader needs to act: what it is,
/// how much is left, what state it is in, and when. The amount shown is the
/// **outstanding** figure rather than the bill's total, because a bill with
/// ₱2,000 paid of ₱2,450 is a ₱450 problem, and showing the total would overstate
/// what the user owes on every partially paid row.
class BillListTile extends ConsumerWidget {
  const BillListTile({required this.item, required this.onTap, super.key});

  final BillWithStatus item;
  final VoidCallback onTap;

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

    return AppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          if (category case final Category value) ...<Widget>[
            CategoryIcon(category: value),
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
                    // Overdue and due-soon rows say so in colour as well as in
                    // words. Colour alone would not be enough, which is why the
                    // words carry it too.
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
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (item.status case final BillStatus status)
                AppStatusChip(label: _label(status), tone: _tone(status)),
            ],
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

  static String _label(BillStatus status) => switch (status) {
    BillStatus.upcoming => 'Upcoming',
    BillStatus.dueSoon => 'Due soon',
    BillStatus.partiallyPaid => 'Part paid',
    BillStatus.overdue => 'Overdue',
    BillStatus.paid => 'Paid',
    BillStatus.archived => 'Archived',
  };

  static AppStatusTone _tone(BillStatus status) => switch (status) {
    BillStatus.paid => AppStatusTone.paid,
    BillStatus.dueSoon => AppStatusTone.dueSoon,
    BillStatus.overdue => AppStatusTone.overdue,
    BillStatus.partiallyPaid => AppStatusTone.info,
    BillStatus.upcoming || BillStatus.archived => AppStatusTone.neutral,
  };
}
