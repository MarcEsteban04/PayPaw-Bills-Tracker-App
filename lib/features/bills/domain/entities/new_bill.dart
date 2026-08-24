import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';

/// A bill the user has described but the database has not yet stored.
///
/// Separate from [Bill] because a [Bill] carries an `id`, a `createdAt` and an
/// `updatedAt`, and the database owns all three. Reusing [Bill] for creation
/// would mean inventing values for them — a placeholder id and a fabricated
/// timestamp — and every one of those is a lie that some later code will believe.
///
/// It also makes the repository's two write paths honest: you create from a
/// draft, and you update from a bill that exists.
///
/// No `userId` either. The repository fills that in from the session, so a caller
/// cannot get it wrong and cannot set it to somebody else.
@immutable
class NewBill {
  const NewBill({
    required this.name,
    required this.amount,
    required this.dueOn,
    this.categoryId,
    this.recurringBillId,
    this.payee,
    this.notes,
  });

  final String name;
  final Money amount;

  /// **Date only**, like [Bill.dueOn].
  final DateTime dueOn;

  final String? categoryId;
  final String? recurringBillId;
  final String? payee;
  final String? notes;

  NewBill copyWith({
    String? name,
    Money? amount,
    DateTime? dueOn,
    String? categoryId,
    String? recurringBillId,
    String? payee,
    String? notes,
  }) => NewBill(
    name: name ?? this.name,
    amount: amount ?? this.amount,
    dueOn: dueOn ?? this.dueOn,
    categoryId: categoryId ?? this.categoryId,
    recurringBillId: recurringBillId ?? this.recurringBillId,
    payee: payee ?? this.payee,
    notes: notes ?? this.notes,
  );

  @override
  bool operator ==(Object other) =>
      other is NewBill &&
      other.name == name &&
      other.amount == amount &&
      other.dueOn == dueOn &&
      other.categoryId == categoryId &&
      other.recurringBillId == recurringBillId &&
      other.payee == payee &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
    name,
    amount,
    dueOn,
    categoryId,
    recurringBillId,
    payee,
    notes,
  );

  @override
  String toString() =>
      'NewBill($name, $amount, due ${dueOn.toIso8601String()})';
}
