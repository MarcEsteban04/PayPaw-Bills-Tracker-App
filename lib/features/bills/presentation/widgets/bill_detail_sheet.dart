import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/widgets/app_bottom_sheet.dart';
import '../../../../core/presentation/widgets/app_status_chip.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/controllers/category_providers.dart';
import '../../../categories/presentation/widgets/category_icon.dart';
import '../../domain/entities/bill_status.dart';
import '../../domain/entities/bill_with_status.dart';
import 'bill_status_display.dart';

/// What the user chose to do from the detail sheet.
enum BillDetailAction { edit, archive, restore, delete }

/// Everything known about one bill, in a drawer.
///
/// ## The shape
///
/// A header carrying the identity and the three actions, one figure large enough
/// to be the answer, and a list of facts beneath it.
///
/// The actions are **icons in the header**, not stacked buttons. Three full-width
/// buttons made a *reading* surface look like a decision — the eye went to the
/// green rectangle before it reached the number the drawer exists to show. As
/// icons they are present, reachable and quiet, and the amount gets to be the
/// loudest thing on the sheet.
///
/// Each carries a tooltip and a semantics label, because an icon on its own has no
/// name. Delete is safe as a bare icon only because it confirms; if that
/// confirmation ever goes, this has to go back to being a labelled button.
///
/// ## Why a sheet and not a screen
///
/// A bill is six fields and three derived numbers, which fits. A drawer also keeps
/// the list behind it, so comparing two bills costs a tap each rather than a push
/// and a pop. Sprint 26 can promote it once there is payment history and there are
/// attachments to show.
///
/// Returns the chosen action, or null if the sheet was dismissed.
Future<BillDetailAction?> showBillDetailSheet({
  required BuildContext context,
  required BillWithStatus item,
}) => showAppBottomSheet<BillDetailAction>(
  context: context,
  child: _BillDetail(item: item),
);

class _BillDetail extends ConsumerWidget {
  const _BillDetail({required this.item});

  final BillWithStatus item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Category? category = switch (ref.watch(categoriesProvider)) {
      AsyncData<List<Category>>(value: final List<Category> all) =>
        all.where((Category c) => c.id == item.bill.categoryId).firstOrNull,
      _ => null,
    };

    final bool isSettled = item.status == BillStatus.paid;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(item: item, category: category),
        const SizedBox(height: AppSpacing.xl),

        // The one figure the drawer exists to show, at the size that says so.
        // It was previously one of two equal rows in a grey box, which made the
        // reader do the work of deciding which number mattered.
        Text(
          isSettled ? 'PAID IN FULL' : 'OUTSTANDING',
          style: textTheme.labelSmall?.copyWith(
            color: colors.textTertiary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          (isSettled ? item.bill.amount : item.outstanding).format(),
          style: textTheme.displaySmall?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),

        // Only when something has been paid but not everything. Otherwise the
        // bar is empty or full, and the line under it repeats the figure above.
        if (item.isPartiallyPaid) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _PaidBar(fraction: _paidFraction(item)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${item.paid.format()} paid of ${item.bill.amount.format()}',
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        Divider(height: 1, color: colors.border),
        const SizedBox(height: AppSpacing.lg),

        // Icon-led rows rather than label/value pairs. The icon is what makes a
        // list of facts scannable — the eye finds the calendar without reading
        // the word "Due".
        _Fact(
          icon: Icons.event_outlined,
          label: 'Due',
          value: DateFormat.yMMMEd().format(item.bill.dueOn),
          detail: isSettled ? null : _relative(item),
          tone: switch (item.status) {
            BillStatus.overdue => colors.overdueText,
            BillStatus.dueSoon => colors.dueSoonText,
            _ => null,
          },
        ),
        if (category case final Category value) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _Fact(
            icon: Icons.sell_outlined,
            label: 'Category',
            value: value.name,
          ),
        ],
        if (item.bill.payee case final String payee) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _Fact(
            icon: Icons.storefront_outlined,
            label: 'Paid to',
            value: payee,
          ),
        ],
        if (item.lastPaidAt case final DateTime paidAt) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _Fact(
            icon: Icons.receipt_long_outlined,
            label: 'Last payment',
            value: DateFormat.yMMMd().format(paidAt),
          ),
        ],
        if (item.bill.notes case final String notes) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _Fact(
            icon: Icons.notes_outlined,
            label: 'Notes',
            value: notes,
            // Notes are prose, not a value. Left to wrap rather than truncated
            // on one line beside its label.
            isProse: true,
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        // Their own row, right-aligned, rather than in the header beside the
        // name. Three 48dp targets, a title and a status chip competing for one
        // line overflowed a 392dp sheet by 22 points once the chip read "Partly
        // paid" — and squeezing the name to fit would have been solving the wrong
        // problem. Down here they also read in the right order: what it is, how
        // much, the details, then what you can do about it.
        Align(
          alignment: Alignment.centerRight,
          child: _Actions(isArchived: item.bill.isArchived),
        ),
      ],
    );
  }

  static double _paidFraction(BillWithStatus item) {
    final int total = item.bill.amount.minorUnits;

    return total <= 0 ? 0 : item.paid.minorUnits / total;
  }

  /// How soon, counted against the row's own `today` rather than the device
  /// clock. See [BillWithStatus.today].
  static String _relative(BillWithStatus item) => switch (item.daysUntilDue) {
    0 => 'Today',
    1 => 'Tomorrow',
    final int days when days < 0 => '${-days} days ago',
    final int days => 'In $days days',
  };
}

/// Identity on the left, actions on the right.
class _Header extends StatelessWidget {
  const _Header({required this.item, required this.category});

  final BillWithStatus item;
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (category case final Category value) ...<Widget>[
          CategoryIcon(category: value, size: 48),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.bill.name,
                style: textTheme.titleLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppStatusChip(
                label: BillStatusDisplay.label(item.status),
                tone: BillStatusDisplay.tone(item.status),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Edit, archive and delete, as icons.
class _Actions extends StatelessWidget {
  const _Actions({required this.isArchived});

  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ActionButton(
          icon: Icons.edit_outlined,
          label: 'Edit',
          foreground: colors.primaryText,
          background: colors.primarySoft,
          action: BillDetailAction.edit,
        ),
        const SizedBox(width: AppSpacing.sm),
        // Restore and archive are the same slot: offering "Archive" on something
        // already archived is a button that does nothing visible.
        _ActionButton(
          icon: isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
          label: isArchived ? 'Restore' : 'Archive',
          foreground: colors.textSecondary,
          background: colors.surfaceMuted,
          action: isArchived
              ? BillDetailAction.restore
              : BillDetailAction.archive,
        ),
        const SizedBox(width: AppSpacing.sm),
        _ActionButton(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          foreground: colors.overdueText,
          background: colors.overdueTint,
          action: BillDetailAction.delete,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.action,
  });

  final IconData icon;

  /// The word the icon does not carry. Used for the tooltip and the semantics.
  final String label;

  final Color foreground;
  final Color background;
  final BillDetailAction action;

  /// Full 48dp, even though the circle is drawn smaller. The tap target is what
  /// has to clear the minimum, not the paint.
  static const double _tapSize = 48;
  static const double _circleSize = 40;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: SizedBox(
          width: _tapSize,
          height: _tapSize,
          child: Center(
            child: Material(
              color: background,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(action),
                child: SizedBox(
                  width: _circleSize,
                  height: _circleSize,
                  child: Center(child: Icon(icon, size: 20, color: foreground)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One fact: an icon, what it is, and what it says.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.tone,
    this.isProse = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// A second line under the value — "In 27 days" beneath a date.
  final String? detail;

  /// Overrides the value's colour, for a date that is late or close.
  final Color? tone;

  /// Whether the value is a paragraph rather than a short value.
  final bool isProse;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: const BorderRadius.all(Radius.circular(AppRadii.xs)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Icon(icon, size: 18, color: colors.textSecondary),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                value,
                style: textTheme.bodyLarge?.copyWith(
                  color: tone ?? colors.textPrimary,
                  fontWeight: isProse ? FontWeight.w400 : FontWeight.w600,
                  height: isProse ? 1.5 : null,
                ),
              ),
              if (detail case final String second) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  second,
                  style: textTheme.bodySmall?.copyWith(
                    color: tone ?? colors.textSecondary,
                    fontWeight: tone == null
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// How much of a part-paid bill has been cleared.
class _PaidBar extends StatelessWidget {
  const _PaidBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Semantics(
      label: 'Paid',
      value: '${(fraction * 100).round()} percent',
      child: ClipRRect(
        borderRadius: AppRadii.round,
        child: SizedBox(
          height: 6,
          child: Stack(
            children: <Widget>[
              ColoredBox(color: colors.surfaceMuted),
              FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: colors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
