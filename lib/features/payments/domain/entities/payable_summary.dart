import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'payment_target.dart';

/// Everything the record-payment sheet needs to know about what is being paid.
///
/// ## Why this exists
///
/// The sheet took a `BillWithStatus`, which was right while bills were the only
/// thing anybody paid. Debts are the second, and there were two ways to serve
/// them: a second sheet, or this.
///
/// A second sheet would have duplicated an amount field, a date picker, a method
/// dropdown, a reference field, a note field and every validator over them —
/// leaving the difference between paying a bill and repaying utang as *six
/// hundred lines of identical form*, with the day they drift already scheduled.
///
/// So the sheet takes a summary instead. Everything bill-shaped about it turned
/// out to be five values and a target, which is what this carries.
@immutable
class PayableSummary {
  const PayableSummary({
    required this.target,
    required this.title,
    required this.subtitle,
    required this.outstanding,
    required this.today,
    required this.settledMessage,
    this.sheetTitle = 'Record payment',
    this.amountLabel = 'Amount paid',
    this.outstandingLabel = 'STILL OWED',
  });

  /// The row a payment against this would point at.
  final PaymentTarget target;

  /// What it is called. A bill's name, or the person the utang is with.
  final String title;

  /// The line beneath it — a due date, usually.
  final String subtitle;

  /// What is still owed. The sheet opens on this figure, because paying the
  /// whole of what is left is the overwhelmingly common case.
  final Money outstanding;

  /// Today in the owner's own zone, from the database. The sheet's date picker
  /// uses it, so it cannot offer a "today" the rest of the screen disagrees
  /// with.
  final DateTime today;

  /// The sheet's own heading, and the word on its button.
  ///
  /// Direction matters here and the sheet cannot know it. Money **you** owe is
  /// paid; money owed **to you** is repaid *by somebody else*, and a sheet
  /// reading "Amount paid" while you count what arrived is a sheet describing
  /// the wrong side of the transaction.
  final String sheetTitle;

  /// The amount field's label. 'Amount paid' or 'Amount received'.
  final String amountLabel;

  /// What the figure beside the title is called.
  final String outstandingLabel;

  /// What to say when a payment clears the whole remaining balance.
  ///
  /// Carried rather than composed, because the right sentence differs by kind
  /// and neither the sheet nor a generic helper should be guessing at it: a bill
  /// is "marked as paid" and utang is "fully repaid", and calling a debt paid
  /// would be the app announcing something the two people have not agreed.
  final String settledMessage;

  /// What to say for a payment that only covers part of it.
  String partialMessage(Money recorded) =>
      '${recorded.format()} recorded against $title';
}
