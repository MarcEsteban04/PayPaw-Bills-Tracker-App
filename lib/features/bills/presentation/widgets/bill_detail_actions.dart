import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../notifications/presentation/widgets/bill_reminder_sheet.dart';
import '../../../payments/presentation/widgets/record_payment_sheet.dart';
import '../../domain/entities/bill_with_status.dart';
import '../controllers/bill_actions_controller.dart';
import 'bill_detail_sheet.dart';

/// Everything that can be done to a bill from its drawer, in one place.
///
/// ## Why this is not on the bills screen any more
///
/// It was, and the calendar wanted the same drawer. Copying the switch would
/// have meant two implementations of "delete this bill", and the one that fell
/// behind would be the one that stopped warning about payments — a dialog that
/// promises something Postgres refuses.
///
/// So the list, the calendar, and anything after them open the same drawer and
/// get the same behaviour, including the parts that are easy to leave out.
///
/// ## The sheet returns an intent rather than doing the work
///
/// Navigation and dialogs need a context that outlives the sheet, and a widget
/// that pops itself and then keeps working is a widget that eventually uses a
/// dead context. The sheet says what was chosen; this acts on it afterwards.
Future<void> openBillDetail({
  required BuildContext context,
  required WidgetRef ref,
  required BillWithStatus item,
}) async {
  final BillDetailAction? action = await showBillDetailSheet(
    context: context,
    item: item,
  );

  if (!context.mounted || action == null) {
    return;
  }

  switch (action) {
    case BillDetailAction.recordPayment:
      await recordPaymentFor(context: context, ref: ref, item: item);
    case BillDetailAction.reminders:
      await showBillReminderSheet(context: context, item: item);
    case BillDetailAction.edit:
      openBillEditor(context, item);
    case BillDetailAction.archive:
      await archiveBill(context: context, ref: ref, item: item);
    case BillDetailAction.restore:
      await ref
          .read(billActionsControllerProvider.notifier)
          .restore(item.bill.id);
    case BillDetailAction.delete:
      await confirmDeleteBill(context: context, ref: ref, item: item);
  }
}

/// Opens the edit form for one bill.
void openBillEditor(BuildContext context, BillWithStatus item) =>
    context.pushNamed(
      AppRoutes.editBill.routeName,
      pathParameters: <String, String>{'id': item.bill.id},
    );

/// Puts a bill away, with a way back.
///
/// The undo is the point: archiving is reversible and the toast is the only
/// place that says so at the moment it matters.
Future<void> archiveBill({
  required BuildContext context,
  required WidgetRef ref,
  required BillWithStatus item,
}) async {
  final BillActionsController controller = ref.read(
    billActionsControllerProvider.notifier,
  );

  if (!await controller.archive(item.bill.id) || !context.mounted) {
    return;
  }

  showAppToast(
    context,
    message: '${item.bill.name} archived',
    actionLabel: 'Undo',
    onAction: () => controller.restore(item.bill.id),
  );
}

/// Asks before deleting, and reports what it did.
///
/// Returns whether the bill is gone, which is also what tells a swipe whether to
/// let the row leave the list.
Future<bool> confirmDeleteBill({
  required BuildContext context,
  required WidgetRef ref,
  required BillWithStatus item,
}) async {
  // A bill with payments cannot be deleted at all.
  //
  // `payments.bill_id` is `on delete restrict`, which the migration calls the
  // thing that makes "archive, do not delete" real. So the dialog used to
  // promise something Postgres refuses: it offered Delete, explained that the
  // payments would go too, and the request came back a foreign key violation.
  if (item.paid.minorUnits > 0) {
    final bool archive = await showAppConfirmDialog(
      context: context,
      title: 'This bill cannot be deleted',
      message:
          'PayPaw has ${item.paid.format()} recorded against '
          '${item.bill.name}, and that history is the record of what you '
          'actually paid. Archive it instead to take it off the list.',
      confirmLabel: 'Archive',
    );

    if (archive && context.mounted) {
      await archiveBill(context: context, ref: ref, item: item);
    }

    return false;
  }

  final bool confirmed = await showAppConfirmDialog(
    context: context,
    title: 'Delete ${item.bill.name}?',
    // "Are you sure?" tells the reader nothing they did not already know.
    message:
        'This cannot be undone. Archive instead if you might want it back.',
    confirmLabel: 'Delete',
    isDestructive: true,
  );

  if (!confirmed) {
    return false;
  }

  final bool deleted = await ref
      .read(billActionsControllerProvider.notifier)
      .delete(item.bill.id);

  if (deleted && context.mounted) {
    showAppToast(
      context,
      message: '${item.bill.name} deleted',
      tone: AppToastTone.success,
    );
  }

  return deleted;
}
