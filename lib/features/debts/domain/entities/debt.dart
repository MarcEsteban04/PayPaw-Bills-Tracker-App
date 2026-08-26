import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'debt_direction.dart';

/// Utang, in either direction, as the app reasons about it.
///
/// The **stored facts only**. What has been repaid and what is left are sums over
/// `public.payments`, which references this table — so they are derived, and
/// putting them here would invite writing them back. A derived value that can be
/// written is a derived value that will eventually be wrong; `Bill` keeps status
/// and outstanding off itself for the same reason.
///
/// Pure Dart: no Flutter, no Supabase, no JSON. The mapping to and from database
/// columns lives in `DebtDto`.
///
/// ## No interest
///
/// The roadmap's Sprint 52 named it and the column does not exist. It is left
/// out by decision rather than oversight — see the sprint entry. The cost is
/// real and worth naming here so nobody adds it by accident later: PayPaw cannot
/// record "borrowed ₱5,000, paying back ₱5,500". [principal] is the whole of
/// what is owed.
@immutable
class Debt {
  const Debt({
    required this.id,
    required this.userId,
    required this.direction,
    required this.counterpartyName,
    required this.principal,
    required this.incurredOn,
    required this.createdAt,
    required this.updatedAt,
    this.counterpartyContact,
    this.dueOn,
    this.notes,
    this.settledAt,
  });

  final String id;
  final String userId;

  /// Which way the money goes. See [DebtDirection].
  final DebtDirection direction;

  /// Who the other party is, as text.
  ///
  /// Text and not a reference to a user, which is what the migration says and
  /// why: the person you owe money to is usually not a PayPaw user, and
  /// requiring them to be would make the feature useless.
  final String counterpartyName;

  /// A phone number, an email, a Viber handle — whatever the user wrote.
  ///
  /// Unvalidated on purpose. It exists to help somebody get in touch, and a
  /// format check would reject "the guy at the sari-sari store" while accepting
  /// a mistyped number.
  final String? counterpartyContact;

  /// The whole of what is owed.
  final Money principal;

  /// When the money changed hands.
  final DateTime incurredOn;

  /// When it is meant to be repaid, or null.
  ///
  /// **Nullable, unlike a bill's due date**, and that is the point. Plenty of
  /// utang has no agreed date, and forcing one would mean inventing a deadline
  /// the user never agreed to — which the app would then dutifully nag about.
  final DateTime? dueOn;

  final String? notes;

  /// When this was fully repaid, or null while it is open.
  ///
  /// Settled rather than deleted, the same reasoning as archiving a bill: the
  /// payments made against it are history, and `payments.debt_id` is
  /// `on delete restrict` precisely so a repaid debt cannot be erased out from
  /// under them.
  final DateTime? settledAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether money is still expected to move.
  bool get isOpen => settledAt == null;

  bool get isSettled => settledAt != null;

  /// Whether a repayment date was ever agreed.
  bool get hasDueDate => dueOn != null;

  /// Whether the agreed date has passed with the debt still open.
  ///
  /// [today] is passed in rather than read from the clock, so this stays pure
  /// and agrees with the dates on the screen around it.
  ///
  /// A debt with no agreed date is **never** late. Nothing was promised, so
  /// nothing has been broken — and treating "no date" as "overdue since day
  /// one" would paint half of somebody's informal lending red.
  bool isOverdue(DateTime today) {
    if (settledAt != null || dueOn == null) {
      return false;
    }

    final DateTime due = DateTime(dueOn!.year, dueOn!.month, dueOn!.day);

    return DateTime(today.year, today.month, today.day).isAfter(due);
  }

  Debt copyWith({
    String? id,
    String? userId,
    DebtDirection? direction,
    String? counterpartyName,
    String? counterpartyContact,
    Money? principal,
    DateTime? incurredOn,
    DateTime? dueOn,
    String? notes,
    DateTime? settledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Debt(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    direction: direction ?? this.direction,
    counterpartyName: counterpartyName ?? this.counterpartyName,
    counterpartyContact: counterpartyContact ?? this.counterpartyContact,
    principal: principal ?? this.principal,
    incurredOn: incurredOn ?? this.incurredOn,
    dueOn: dueOn ?? this.dueOn,
    notes: notes ?? this.notes,
    settledAt: settledAt ?? this.settledAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Clears the nullable fields, which [copyWith] cannot. See `Bill.clearing`.
  ///
  /// Settling and un-settling both go through here rather than through
  /// `copyWith`, because "no longer settled" is a null and `copyWith` reads a
  /// null as "leave it alone".
  Debt clearing({
    bool contact = false,
    bool dueOn = false,
    bool notes = false,
    bool settledAt = false,
  }) => Debt(
    id: id,
    userId: userId,
    direction: direction,
    counterpartyName: counterpartyName,
    counterpartyContact: contact ? null : counterpartyContact,
    principal: principal,
    incurredOn: incurredOn,
    dueOn: dueOn ? null : this.dueOn,
    notes: notes ? null : this.notes,
    settledAt: settledAt ? null : this.settledAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Debt && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Debt(${direction.name}, $counterpartyName, $principal, '
      'due $dueOn, settled $settledAt)';
}
