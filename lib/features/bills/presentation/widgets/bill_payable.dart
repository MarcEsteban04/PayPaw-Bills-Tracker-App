import 'package:intl/intl.dart';

import '../../../payments/domain/entities/payable_summary.dart';
import '../../../payments/domain/entities/payment_target.dart';
import '../../domain/entities/bill_with_status.dart';

/// Describes a bill to the record-payment sheet.
///
/// One place rather than three. The sheet stopped taking a `BillWithStatus` when
/// debts became a second thing anybody pays — see [PayableSummary] — and the
/// wording that turns a bill into one belongs here, in the feature that knows
/// what a bill is called and what "settled" means for it.
///
/// The dependency runs bills → payments, which is the direction it already ran.
/// Putting this in the payments feature instead would have it importing bills to
/// describe them, and the sheet is now free of that.
PayableSummary billPayable(BillWithStatus item) => PayableSummary(
  target: PaymentTarget.bill(item.bill.id),
  title: item.bill.name,
  subtitle: 'Due ${DateFormat.MMMd().format(item.bill.dueOn)}',
  outstanding: item.outstanding,
  // The bill's own row, not the device clock — the same date its status was
  // computed against.
  today: item.today,
  settledMessage: '${item.bill.name} marked as paid',
);
