import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/widgets/app_bottom_sheet.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../payments/presentation/widgets/record_payment_sheet.dart';
import '../../domain/entities/debt_with_status.dart';
import '../controllers/debt_write_controller.dart';
import 'debt_payable.dart';

/// What the user chose to do from the detail sheet.
enum DebtAction { recordPayment, edit, settle, reopen, delete }

/// Everything known about one debt, in a drawer.
///
/// Opens the sheet and acts on whatever came back. The sheet returns an intent
/// rather than doing the work itself: navigation and dialogs need a context that
/// outlives the sheet, and a widget that pops itself and then keeps working is a
/// widget that eventually uses a dead context.
Future<void> showDebtDetailSheet({
  required BuildContext context,
  required WidgetRef ref,
  required DebtWithStatus item,
}) async {
  final DebtAction? action = await showAppBottomSheet<DebtAction>(
    context: context,
    child: _DebtDetail(item: item),
  );

  if (!context.mounted || action == null) {
    return;
  }

  final DebtWriteController controller = ref.read(
    debtWriteControllerProvider.notifier,
  );

  switch (action) {
    case DebtAction.recordPayment:
      // Through the shared sheet, which already knows how to record money
      // moving. A debt-only repayment form would be six hundred lines of
      // identical fields — see PayableSummary.
      await recordPaymentFor(
        context: context,
        ref: ref,
        payable: debtPayable(item),
      );
    case DebtAction.edit:
      unawaited(
        context.pushNamed(
          AppRoutes.editDebt.routeName,
          pathParameters: <String, String>{'id': item.id},
        ),
      );
    case DebtAction.settle:
      await _settle(context, controller, item);
    case DebtAction.reopen:
      await controller.reopen(item.id);
    case DebtAction.delete:
      await _confirmDelete(context, controller, item);
  }
}

/// Closes a debt, warning first when the numbers do not agree.
Future<void> _settle(
  BuildContext context,
  DebtWriteController controller,
  DebtWithStatus item,
) async {
  // Only asks when the arithmetic disagrees. Settling a debt whose payments
  // already sum to the principal is bookkeeping and needs no ceremony; settling
  // one with money still on it is a decision, and worth naming out loud.
  if (!item.isFullyRepaid) {
    final bool confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Close this without the rest?',
      message:
          '${item.outstanding.format()} of ${item.principal.format()} has not '
          'been recorded as repaid. Closing it says the two of you are done '
          'anyway — PayPaw will stop counting it either way.',
      confirmLabel: 'Close it',
    );

    if (!confirmed) {
      return;
    }
  }

  final Object? settled = await controller.settle(item.id);

  if (settled != null && context.mounted) {
    showAppToast(
      context,
      message: '${item.counterpartyName} settled',
      tone: AppToastTone.success,
    );
  }
}

/// Asks before deleting, and says what the database will refuse.
Future<void> _confirmDelete(
  BuildContext context,
  DebtWriteController controller,
  DebtWithStatus item,
) async {
  final bool confirmed = await showAppConfirmDialog(
    context: context,
    title: 'Delete this record?',
    // Says which of the two operations they probably want. Deleting is for
    // something typed by mistake; a debt that was really repaid should be
    // settled, and the database will refuse to delete one with repayments
    // against it anyway.
    message: item.paymentCount > 0
        ? 'This has ${item.paymentCount} '
              '${item.paymentCount == 1 ? 'repayment' : 'repayments'} recorded '
              'against it, so it cannot be deleted. Close it instead if the two '
              'of you are done.'
        : 'This removes the record entirely. If it was really repaid, close it '
              'instead — that keeps the history.',
    confirmLabel: 'Delete',
    isDestructive: true,
  );

  if (!confirmed) {
    return;
  }

  final bool deleted = await controller.delete(item.id);

  if (deleted && context.mounted) {
    showAppToast(context, message: 'Deleted', tone: AppToastTone.success);
  }
}

class _DebtDetail extends StatelessWidget {
  const _DebtDetail({required this.item});

  final DebtWithStatus item;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            item.counterpartyName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            item.direction.isOutgoing ? 'YOU STILL OWE' : 'STILL OWED TO YOU',
            style: textTheme.labelSmall?.copyWith(
              color: colors.textTertiary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.outstanding.format(),
            style: textTheme.displaySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          if (item.repaid.minorUnits > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${item.repaid.format()} of ${item.principal.format()} repaid',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: AppSpacing.lg),

          _Fact(
            icon: Icons.event_outlined,
            label: 'To be repaid by',
            value: switch (item.debt.dueOn) {
              null => 'No date agreed',
              final DateTime due => DateFormat.yMMMEd().format(due),
            },
            tone: item.isOverdue ? colors.overdueText : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _Fact(
            icon: Icons.history_rounded,
            label: 'Since',
            value: DateFormat.yMMMEd().format(item.debt.incurredOn),
          ),
          _Fact.optional(
            icon: Icons.call_outlined,
            label: 'Contact',
            value: item.debt.counterpartyContact,
          ),
          _Fact.optional(
            icon: Icons.notes_rounded,
            label: 'Notes',
            value: item.debt.notes,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Recording a repayment is the thing this drawer is opened for, so it
          // leads — and it is absent once the debt is closed, because a settled
          // debt is not accepting money.
          if (item.isOpen) ...<Widget>[
            _Action(
              icon: Icons.payments_outlined,
              label: 'Record a repayment',
              onPressed: () =>
                  Navigator.of(context).pop(DebtAction.recordPayment),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          _Action(
            icon: Icons.edit_outlined,
            label: 'Edit',
            onPressed: () => Navigator.of(context).pop(DebtAction.edit),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Action(
            icon: item.isOpen
                ? Icons.check_circle_outline_rounded
                : Icons.undo_rounded,
            label: item.isOpen ? 'Close it' : 'Open it again',
            onPressed: () =>
                Navigator.of(context)
                    .pop(item.isOpen ? DebtAction.settle : DebtAction.reopen),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Action(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            isDestructive: true,
            onPressed: () => Navigator.of(context).pop(DebtAction.delete),
          ),
        ],
      ),
    );
  }
}

/// One labelled fact.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.tone,
  });

  /// Renders nothing when the value is absent, gap included.
  ///
  /// A contact nobody recorded should not leave a labelled blank on the sheet.
  const _Fact.optional({
    required this.icon,
    required this.label,
    required String? value,
  }) : value = value ?? '',
       tone = null;

  final IconData icon;
  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: AppRadii.chip,
            ),
            child: Icon(icon, size: 18, color: colors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  style: textTheme.titleSmall?.copyWith(
                    color: tone ?? colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One thing you can do, as a full-width row.
class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Color foreground = isDestructive
        ? colors.overdueText
        : colors.textPrimary;

    return Material(
      color: isDestructive ? colors.overdueTint : colors.surfaceMuted,
      borderRadius: AppRadii.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: AppSpacing.md),
              Text(
                label,
                style: textTheme.bodyLarge?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
