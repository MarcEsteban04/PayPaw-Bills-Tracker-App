import 'package:intl/intl.dart';

import '../../../payments/domain/entities/payable_summary.dart';
import '../../../payments/domain/entities/payment_target.dart';
import '../../domain/entities/debt_with_status.dart';

/// Describes a debt to the record-payment sheet.
///
/// The sibling of `billPayable`, and it lives here for the same reason: the
/// feature that knows what a debt is called is the one that should word it.
///
/// ## "Fully repaid", not "paid"
///
/// A bill clearing its balance is *paid* — that is the whole of the
/// relationship. A debt clearing its balance is only the arithmetic being
/// square: whether the utang is finished is something two people agree, and
/// `settled_at` is where that agreement lives. So the sheet says the numbers are
/// met and stops short of closing anything.
PayableSummary debtPayable(DebtWithStatus item) => PayableSummary(
  // Direction changes who is handing over the money, and every label that
  // mentions it. "Amount paid" is right for the utang you owe and wrong for the
  // utang owed to you, where somebody is paying *you* and the figure on screen
  // is what arrived.
  sheetTitle: item.direction.isOutgoing
      ? 'Record a repayment'
      : 'Record what they paid',
  amountLabel: item.direction.isOutgoing ? 'Amount paid' : 'Amount received',
  outstandingLabel: item.direction.isOutgoing
      ? 'YOU STILL OWE'
      : 'STILL OWED TO YOU',
  target: PaymentTarget.debt(item.id),
  title: item.counterpartyName,
  subtitle: switch (item.debt.dueOn) {
    // A debt with no agreed date says so rather than showing a blank line. It is
    // the difference between something somebody promised and something they did
    // not.
    null => 'No date agreed',
    final DateTime due =>
      '${item.isOverdue ? 'Was due' : 'Due'} ${DateFormat.MMMd().format(due)}',
  },
  outstanding: item.outstanding,
  today: item.today,
  settledMessage: '${item.counterpartyName} fully repaid',
);
