import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_bottom_sheet.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../bills/domain/entities/bill_status.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import '../../../bills/presentation/widgets/bill_list_tile.dart';

/// Asks which bill was paid.
///
/// The dashboard's "Mark paid" has no bill in hand — unlike the detail drawer,
/// which is already looking at one — so it has to ask before it can do anything.
/// This is that question, and nothing more: no search, no filters, no sort. The
/// Bills tab is where a list gets those, and putting them here would rebuild that
/// screen inside a sheet.
///
/// **Late first, then soonest.** The bill somebody has just paid is overwhelmingly
/// the one that was worrying them, and a list ordered by anything else makes them
/// hunt for it.
///
/// Returns the chosen bill, or null if the sheet was dismissed.
Future<BillWithStatus?> showPayBillPicker({
  required BuildContext context,
  required List<BillWithStatus> bills,
}) => showAppBottomSheet<BillWithStatus>(
  context: context,
  title: 'Which bill did you pay?',
  child: _PayBillPicker(bills: payableBills(bills)),
);

/// Bills a payment can be recorded against, in the order they should be offered.
///
/// Exposed so a caller can ask whether there are any *before* offering the action
/// — an entry point that opens onto an empty sheet is worse than one that is not
/// there.
///
/// Excludes settled bills, which have nothing left to pay, and archived ones,
/// which the user put away. Both would be a row whose result is invisible from
/// the list it was chosen in.
List<BillWithStatus> payableBills(List<BillWithStatus> bills) {
  final List<BillWithStatus> payable =
      bills
          .where(
            (BillWithStatus b) =>
                !b.bill.isArchived && (b.status?.isOutstanding ?? false),
          )
          .toList()
        ..sort((BillWithStatus a, BillWithStatus b) {
          final bool aLate = a.status == BillStatus.overdue;
          final bool bLate = b.status == BillStatus.overdue;

          if (aLate != bLate) {
            return aLate ? -1 : 1;
          }

          return a.bill.dueOn.compareTo(b.bill.dueOn);
        });

  return payable;
}

class _PayBillPicker extends StatelessWidget {
  const _PayBillPicker({required this.bills});

  final List<BillWithStatus> bills;

  @override
  Widget build(BuildContext context) {
    // Shrink-wrapped inside the sheet's own scroll behaviour rather than given a
    // fixed height: three bills should not leave two-thirds of a sheet empty, and
    // thirty should still scroll.
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: bills.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.cardGap),
      itemBuilder: (BuildContext context, int index) {
        final BillWithStatus item = bills[index];

        return BillListTile(
          item: item,
          onTap: () => Navigator.of(context).pop(item),
        );
      },
    );
  }
}
