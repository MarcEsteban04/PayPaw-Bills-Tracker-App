import '../../../../core/theme/app_palette.dart';
import '../../domain/entities/bill_status.dart';

/// How a [BillStatus] is written and coloured.
///
/// One place, because three widgets want it: the list row's badge, the detail
/// drawer's chip, and the drawer's status line. Two of those had their own copy of
/// the switch, which is two chances for "Partly paid" and "Part paid" to end up on
/// the same screen.
///
/// A presentation concern rather than a domain one — [BillStatus] is pure Dart and
/// stays that way, so nothing here belongs on the enum itself.
abstract final class BillStatusDisplay {
  /// The status in full, for a chip or a labelled row.
  ///
  /// Null becomes 'Unknown' rather than throwing: the view can emit a status this
  /// build has not been taught, and a bill the user was only reading should not
  /// crash on it.
  static String label(BillStatus? status) => switch (status) {
    BillStatus.upcoming => 'Upcoming',
    BillStatus.dueSoon => 'Due soon',
    BillStatus.dueToday => 'Due today',
    BillStatus.partiallyPaid => 'Partly paid',
    BillStatus.overdue => 'Overdue',
    BillStatus.paid => 'Settled',
    BillStatus.archived => 'Archived',
    null => 'Unknown',
  };

  /// The badge for a list row, or null where the row's date already says it.
  ///
  /// Overdue, due-today and due-soon are urgent enough to repeat. Part-paid is the
  /// one a date cannot express at all — a bill can be half settled and not due for
  /// weeks. Everything else would be furniture.
  static String? badge(BillStatus? status) => switch (status) {
    BillStatus.overdue => 'OVERDUE',
    BillStatus.dueToday => 'DUE TODAY',
    BillStatus.dueSoon => 'DUE SOON',
    BillStatus.partiallyPaid => 'PART PAID',
    _ => null,
  };

  /// Which colour pair the status wears.
  ///
  /// Due-today shares the due-soon tone rather than getting one of its own. A
  /// tone is a pair of theme colours, and inventing a fourth urgency colour to sit
  /// between amber and red would give the palette a distinction the eye cannot
  /// reliably make. The word carries the difference; the colour says "not late
  /// yet, but close".
  static AppStatusTone tone(BillStatus? status) => switch (status) {
    BillStatus.paid => AppStatusTone.paid,
    BillStatus.dueSoon || BillStatus.dueToday => AppStatusTone.dueSoon,
    BillStatus.overdue => AppStatusTone.overdue,
    BillStatus.partiallyPaid => AppStatusTone.info,
    BillStatus.upcoming || BillStatus.archived || null => AppStatusTone.neutral,
  };
}
