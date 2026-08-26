import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'recurrence.dart';

/// What kind of repeating obligation a template describes.
///
/// **A subscription is a recurring obligation** — same recurrence, same amount,
/// same generation — so it shares this table rather than getting one of its own.
/// A second table would mean a second copy of all of that, and the day the two
/// drift is the day monthly bills work and monthly subscriptions do not.
/// Subscription-only fields live in the extension table in migration 0006.
///
/// Matches the `kind` check constraint in `0005_recurring_bills.sql`.
enum RecurringBillKind {
  bill('bill'),
  subscription('subscription');

  const RecurringBillKind(this.wireValue);

  final String wireValue;

  /// Unknown values fall back to [bill] rather than null.
  ///
  /// Unlike a status, this one is safe to default: the column is `not null` with a
  /// default of `'bill'`, and a template the app cannot classify is still a
  /// template that has to appear in a list. Guessing "bill" shows it; a null would
  /// mean every screen carrying a nullable kind for a case that cannot happen.
  static RecurringBillKind parse(String? value) {
    for (final RecurringBillKind kind in values) {
      if (kind.wireValue == value) {
        return kind;
      }
    }

    return RecurringBillKind.bill;
  }
}

/// The template for an obligation that repeats.
///
/// Individual occurrences are rows in `bills`, each carrying this template's id in
/// `recurring_bill_id`. Nothing has ever set that column — Sprint 31 is where
/// generation starts filling it in.
///
/// **Composes a [Recurrence]** rather than flattening its seven columns in here.
/// The schedule is a thing with its own rules and its own arithmetic, and a
/// template that carried `dayOfMonth` directly would put every caller one field
/// access away from doing date maths itself.
@immutable
class RecurringBill {
  const RecurringBill({
    required this.id,
    required this.userId,
    required this.kind,
    required this.name,
    required this.amount,
    required this.recurrence,
    required this.nextDueOn,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.payee,
  });

  final String id;
  final String userId;

  /// Null when the category was deleted — the column is `on delete set null`, so
  /// deleting a category never deletes what was filed under it.
  final String? categoryId;

  final RecurringBillKind kind;
  final String name;
  final String? payee;
  final Money amount;

  /// When it falls due, as a rule.
  final Recurrence recurrence;

  /// The occurrence that has not been generated yet.
  ///
  /// **A bookmark, not a derived value.** It is what makes generation idempotent:
  /// generation reads it, creates that one bill, then advances it. Recomputing it
  /// from the recurrence instead would mean generating the same bill twice
  /// whenever a run was interrupted, because nothing would record how far it got.
  ///
  /// It can therefore disagree with the recurrence — after the rule is edited, or
  /// after a manual skip. That is a feature. See [isBookmarkConsistent].
  final DateTime nextDueOn;

  /// Whether generation should keep producing occurrences.
  ///
  /// Pausing is Sprint 32. Distinct from an [Recurrence.endsOn] in the past: a
  /// paused template is one the user intends to resume, and a finished one is
  /// over.
  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether [nextDueOn] is a date this rule could actually produce.
  ///
  /// Not enforced anywhere, and deliberately not repaired automatically — a
  /// bookmark that silently moved would be worse than one that is visibly out of
  /// step. Sprint 32 decides what editing a rule does to it; this is the check
  /// that lets it decide.
  bool get isBookmarkConsistent {
    final DateTime? occurrence = recurrence.occurrenceAfter(
      nextDueOn.subtract(const Duration(days: 1)),
    );

    return occurrence == nextDueOn;
  }

  /// Whether the rule has produced everything it is ever going to.
  bool get isFinished {
    if (recurrence.endsOn case final DateTime end) {
      return nextDueOn.isAfter(end);
    }

    return false;
  }

  /// This template under a different rule, with its bookmark moved to suit.
  ///
  /// [nextDueOn] is a bookmark rather than a derived value, so changing the rule
  /// leaves it pointing at a date the new rule may never produce — which
  /// generation would either skip forever or satisfy on a day nobody chose.
  ///
  /// The bookmark moves to the first date the new rule falls due **on or after
  /// the current bookmark**, never earlier: everything before it has already
  /// been generated, and regenerating it would bill somebody a second time for a
  /// month they already have. Moving the rule's start *forward* therefore
  /// delays the next occurrence, and moving it back does nothing — the safe
  /// direction of the two.
  ///
  /// A rule that produces nothing from there on is finished, so the template
  /// comes back paused with its bookmark untouched. [isActive] is otherwise left
  /// alone: editing a paused template's schedule is not a request to resume it.
  RecurringBill rescheduled(Recurrence rule) {
    final DateTime? bookmark = rule.occurrenceAfter(
      DateTime(nextDueOn.year, nextDueOn.month, nextDueOn.day - 1),
    );

    if (bookmark == null) {
      return copyWith(recurrence: rule, isActive: false);
    }

    return copyWith(recurrence: rule, nextDueOn: bookmark);
  }

  RecurringBill copyWith({
    String? id,
    String? userId,
    String? categoryId,
    RecurringBillKind? kind,
    String? name,
    String? payee,
    Money? amount,
    Recurrence? recurrence,
    DateTime? nextDueOn,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RecurringBill(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    categoryId: categoryId ?? this.categoryId,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    payee: payee ?? this.payee,
    amount: amount ?? this.amount,
    recurrence: recurrence ?? this.recurrence,
    nextDueOn: nextDueOn ?? this.nextDueOn,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Clears the nullable fields, which [copyWith] cannot. See `Bill.clearing`.
  RecurringBill clearing({bool category = false, bool payee = false}) =>
      RecurringBill(
        id: id,
        userId: userId,
        categoryId: category ? null : categoryId,
        kind: kind,
        name: name,
        payee: payee ? null : this.payee,
        amount: amount,
        recurrence: recurrence,
        nextDueOn: nextDueOn,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RecurringBill && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'RecurringBill($name, ${recurrence.describe()}, next $nextDueOn)';
}
