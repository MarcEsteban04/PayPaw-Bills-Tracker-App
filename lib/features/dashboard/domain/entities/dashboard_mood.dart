import '../../../bills/domain/entities/bill_totals.dart';

/// How the bills are going, as far as the mascot is concerned.
///
/// ## Why this is its own type
///
/// The alternative is a chain of ternaries inside the hero card picking a file
/// name. That puts a rule about *money* — when is somebody in trouble, when are
/// they done — inside a widget, where the only way to check it is to pump a
/// screen and look at an image path.
///
/// So the rule lives here as a pure function over the totals, and the widget
/// asks. Which mascot appears is then a fact a test can assert in a line.
///
/// ## The order is the whole design
///
/// The cases are checked in the order declared, and that order is a judgement
/// rather than a formality:
///
/// **Overdue outranks everything.** Somebody three quarters settled with one
/// bill a fortnight late is not three quarters of the way to fine — the late
/// bill is the fact of their week, and a mascot celebrating progress over it
/// would be the app looking away from the one thing it exists to point at.
///
/// **Settled outranks partial**, obviously, and **partial outranks nothing**.
enum DashboardMood {
  /// Something is past its due date and still unpaid.
  overdue('overdue.png'),

  /// Everything billed has been paid.
  allSettled('all_settled.png'),

  /// Some of it has been paid, none of it is late.
  someSettled('some_settled.png'),

  /// Nothing has been paid yet, and nothing is late either.
  ///
  /// Also what somebody with no bills at all sees. A dashboard with nothing on
  /// it is not a failure state and should not be given a sad face: it is a new
  /// account, or a month that has not started.
  noneSettled('none_settled.png');

  const DashboardMood(this.fileName);

  /// The artwork for this mood, inside `assets/images/mascots/`.
  final String fileName;

  /// The full asset path.
  String get assetPath => 'assets/images/mascots/$fileName';

  /// Reads the mood off the figures.
  ///
  /// [hasOverdue] is passed separately rather than derived from [totals],
  /// because `BillTotals` measures amounts and being late is a fact about
  /// *dates* — the screen already computes the overdue list to render it, and
  /// working it out a second time from a different input is how two parts of one
  /// card come to disagree.
  static DashboardMood of(BillTotals totals, {required bool hasOverdue}) {
    if (hasOverdue) {
      return DashboardMood.overdue;
    }

    // Nothing billed is not "all settled". Zero of zero is arithmetically
    // complete and it would put a trophy on an empty account, which reads as
    // mockery the first time somebody opens the app.
    if (!totals.hasProgress) {
      return DashboardMood.noneSettled;
    }

    if (totals.settled >= totals.billed) {
      return DashboardMood.allSettled;
    }

    if (totals.settled.minorUnits > 0) {
      return DashboardMood.someSettled;
    }

    return DashboardMood.noneSettled;
  }
}
