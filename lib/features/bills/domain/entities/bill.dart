import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';

/// One dated obligation, as the app reasons about it.
///
/// The **stored facts only**. Status, amount paid and amount outstanding are
/// derived by the `bill_status` view and are not fields here — putting them on
/// this class would invite writing them back, and a derived value that can be
/// written is a derived value that will eventually be wrong.
///
/// Pure Dart: no Flutter, no Supabase, no JSON. The mapping to and from database
/// columns lives in `BillDto`.
@immutable
class Bill {
  const Bill({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.dueOn,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.recurringBillId,
    this.payee,
    this.notes,
    this.archivedAt,
  });

  final String id;
  final String userId;

  /// Null when the category has been deleted — bills survive their category.
  final String? categoryId;

  /// Set when this bill was generated from a recurring template. Survives the
  /// template being deleted, because a paid occurrence is history.
  final String? recurringBillId;

  /// What the user calls it: "Meralco electricity".
  final String name;

  /// Who it is paid to. Often the same as [name], which is why it is optional.
  final String? payee;

  final Money amount;

  /// **Date only.** The year, month and day are meaningful; the time is always
  /// midnight and means nothing.
  ///
  /// A bill is due *on a day*, not at an instant. The database column is a
  /// `date` for the same reason — stored with a timezone, a bill due on the 1st
  /// reads as due on the 31st for someone who travels.
  final DateTime dueOn;

  final String? notes;

  /// Set when the user archives it. Archived rather than deleted, because a bill
  /// with payment history cannot be removed without taking the history with it.
  final DateTime? archivedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether the user has put this away.
  bool get isArchived => archivedAt != null;

  Bill copyWith({
    String? id,
    String? userId,
    String? name,
    Money? amount,
    DateTime? dueOn,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? categoryId,
    String? recurringBillId,
    String? payee,
    String? notes,
    DateTime? archivedAt,
  }) {
    return Bill(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueOn: dueOn ?? this.dueOn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryId: categoryId ?? this.categoryId,
      recurringBillId: recurringBillId ?? this.recurringBillId,
      payee: payee ?? this.payee,
      notes: notes ?? this.notes,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  /// Clears a nullable field, which [copyWith] cannot express — passing null to
  /// copyWith means "leave it alone", so there has to be another way to say
  /// "remove it".
  Bill clearing({
    bool category = false,
    bool payee = false,
    bool notes = false,
    bool archived = false,
  }) {
    return Bill(
      id: id,
      userId: userId,
      name: name,
      amount: amount,
      dueOn: dueOn,
      createdAt: createdAt,
      updatedAt: updatedAt,
      categoryId: category ? null : categoryId,
      recurringBillId: recurringBillId,
      payee: payee ? null : this.payee,
      notes: notes ? null : this.notes,
      archivedAt: archived ? null : archivedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Bill &&
      other.id == id &&
      other.userId == userId &&
      other.categoryId == categoryId &&
      other.recurringBillId == recurringBillId &&
      other.name == name &&
      other.payee == payee &&
      other.amount == amount &&
      other.dueOn == dueOn &&
      other.notes == notes &&
      other.archivedAt == archivedAt &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    categoryId,
    recurringBillId,
    name,
    payee,
    amount,
    dueOn,
    notes,
    archivedAt,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'Bill($id, $name, $amount, due ${dueOn.toIso8601String()})';
}
