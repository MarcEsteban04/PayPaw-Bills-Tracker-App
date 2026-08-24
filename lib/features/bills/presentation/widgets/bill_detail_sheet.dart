import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/widgets/app_bottom_sheet.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/controllers/category_providers.dart';
import '../../../categories/presentation/widgets/category_icon.dart';
import '../../domain/entities/bill_status.dart';
import '../../domain/entities/bill_with_status.dart';

/// What the user chose to do from the detail sheet.
enum BillDetailAction { edit, archive, restore, delete }

/// Everything known about one bill, in a drawer.
///
/// ## Why a sheet and not a screen
///
/// Sprint 26 will want a full screen once there is payment history and there are
/// attachments to show. Today a bill is six fields and three derived numbers,
/// which fits in a drawer — and a drawer keeps the list behind it, so glancing at
/// one bill and then another costs a tap each rather than a push and a pop.
///
/// ## Why the tap opens this instead of the editor
///
/// Tapping a row used to go straight to the edit form, which meant looking at a
/// bill and changing it were the same gesture. Most taps are looks. Editing is now
/// a deliberate button inside the sheet, and the destructive actions are further
/// in still.
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
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
                    ),
                  ),
                  if (category case final Category value)
                    Text(
                      value.name,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // The three money figures together, because the interesting one is the
        // relationship between them. Outstanding on its own does not say whether
        // a bill is untouched or nearly settled.
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: AppRadii.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: <Widget>[
                _Line(label: 'Amount', value: item.bill.amount.format()),
                if (item.paid.minorUnits > 0) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _Line(label: 'Paid', value: item.paid.format()),
                ],
                const SizedBox(height: AppSpacing.sm),
                _Line(
                  label: 'Outstanding',
                  value: item.outstanding.format(),
                  emphasise: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        _Line(label: 'Due', value: _dueLine(item)),
        const SizedBox(height: AppSpacing.sm),
        _Line(label: 'Status', value: _statusLabel(item.status)),
        if (item.bill.payee case final String payee) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _Line(label: 'Paid to', value: payee),
        ],
        if (item.lastPaidAt case final DateTime paidAt) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _Line(
            label: 'Last payment',
            value: DateFormat.yMMMd().format(paidAt),
          ),
        ],

        if (item.bill.notes case final String notes) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'NOTES',
            style: textTheme.labelSmall?.copyWith(
              color: colors.textTertiary,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            notes,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.sectionGap),

        AppPrimaryButton(
          label: 'Edit bill',
          onPressed: () => Navigator.of(context).pop(BillDetailAction.edit),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Archive before delete, and worded as the reversible one. A bill with
        // payments recorded against it cannot be deleted without taking that
        // history too, so the safe action is the one offered first.
        if (item.bill.isArchived)
          AppSecondaryButton(
            label: 'Restore',
            onPressed: () =>
                Navigator.of(context).pop(BillDetailAction.restore),
          )
        else
          AppSecondaryButton(
            label: 'Archive',
            onPressed: () =>
                Navigator.of(context).pop(BillDetailAction.archive),
          ),
        const SizedBox(height: AppSpacing.sm),
        AppDangerButton(
          label: 'Delete',
          onPressed: () => Navigator.of(context).pop(BillDetailAction.delete),
        ),
      ],
    );
  }

  /// The date, and how soon — counted against the row's own `today` rather than
  /// the device clock. See [BillWithStatus.today].
  static String _dueLine(BillWithStatus item) {
    final String date = DateFormat.yMMMEd().format(item.bill.dueOn);

    if (item.status == BillStatus.paid) {
      return date;
    }

    final String relative = switch (item.daysUntilDue) {
      0 => 'today',
      1 => 'tomorrow',
      final int days when days < 0 => '${-days} days ago',
      final int days => 'in $days days',
    };

    return '$date · $relative';
  }

  static String _statusLabel(BillStatus? status) => switch (status) {
    BillStatus.upcoming => 'Upcoming',
    BillStatus.dueSoon => 'Due soon',
    BillStatus.partiallyPaid => 'Partly paid',
    BillStatus.overdue => 'Overdue',
    BillStatus.paid => 'Settled',
    BillStatus.archived => 'Archived',
    // The view emitted something this build does not know. Shown as unknown
    // rather than guessed at, and never as a crash.
    null => 'Unknown',
  };
}

/// A label on the left, a value on the right.
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final String label;
  final String value;

  /// For the one figure the reader came for.
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: (emphasise ? textTheme.titleMedium : textTheme.bodyMedium)
                ?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}
