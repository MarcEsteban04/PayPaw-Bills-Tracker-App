import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/new_bill.dart';
import '../widgets/bill_form.dart';
import 'bill_repository_provider.dart';

/// Whether a write is in flight, and what it said if it failed.
///
/// Deliberately small. The form owns the fields — see [BillForm] — so what is
/// left here is only what has to outlive a rebuild of them.
class BillWriteState {
  const BillWriteState({this.isSaving = false, this.errorMessage, this.saved});

  final bool isSaving;

  /// A failure, in words safe to show.
  final String? errorMessage;

  /// Set once the write succeeded. The screen watches for it and leaves.
  final Bill? saved;

  BillWriteState copyWith({
    bool? isSaving,
    String? errorMessage,
    Bill? saved,
    bool clearError = false,
  }) => BillWriteState(
    isSaving: isSaving ?? this.isSaving,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    saved: saved ?? this.saved,
  );
}

/// Creates and updates bills.
///
/// One controller for both, because the two differ only in which repository
/// method they call and what they send. Everything around that — the in-flight
/// flag, mapping a failure to a message, reporting success once so the screen can
/// leave — is identical, and two copies of it would be two places to fix the next
/// error-handling bug.
class BillWriteController extends Notifier<BillWriteState> {
  @override
  BillWriteState build() => const BillWriteState();

  void clearError() => state = state.copyWith(clearError: true);

  /// Stores a new bill.
  Future<bool> create(BillFormValues values) =>
      _write(() => ref.read(billRepositoryProvider).createBill(_draft(values)));

  /// Saves changes to one that exists.
  ///
  /// Takes the original bill as well as the values, because an update sends the
  /// whole row: the fields the form does not offer — the id, the owner, the
  /// recurrence link — have to come from somewhere, and inventing them is how a
  /// generated occurrence loses its link to its template.
  Future<bool> update(Bill original, BillFormValues values) => _write(
    () =>
        ref.read(billRepositoryProvider).updateBill(_applyTo(original, values)),
  );

  /// Builds the insert. Empty is not the same as absent: a blank payee means "no
  /// payee", which is a null column, not an empty string that formats later as a
  /// stray blank line.
  NewBill _draft(BillFormValues values) => NewBill(
    name: values.name.trim(),
    amount: values.money!,
    dueOn: values.dueOn!,
    categoryId: values.categoryId,
    payee: _orNull(values.payee),
    notes: _orNull(values.notes),
  );

  /// Applies the form's six fields to an existing bill, leaving everything else
  /// as it was.
  ///
  /// `clearing` rather than `copyWith` for the nullable three: passing null to
  /// copyWith means "leave it alone", so clearing a category or emptying the
  /// notes would silently do nothing. That is exactly the bug the two methods
  /// exist to keep apart.
  Bill _applyTo(Bill original, BillFormValues values) {
    final String? payee = _orNull(values.payee);
    final String? notes = _orNull(values.notes);

    return original
        .copyWith(
          name: values.name.trim(),
          amount: values.money,
          dueOn: values.dueOn,
          categoryId: values.categoryId,
          payee: payee,
          notes: notes,
        )
        .clearing(
          category: values.categoryId == null,
          payee: payee == null,
          notes: notes == null,
        );
  }

  Future<bool> _write(Future<Bill> Function() action) async {
    if (state.isSaving) {
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      state = state.copyWith(isSaving: false, saved: await action());
      return true;
    } on AppException catch (exception) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: exception.userMessage,
      );
      return false;
    } on Object {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }

  static String? _orNull(String? value) {
    final String trimmed = (value ?? '').trim();

    return trimmed.isEmpty ? null : trimmed;
  }
}

final NotifierProvider<BillWriteController, BillWriteState>
billWriteControllerProvider =
    NotifierProvider<BillWriteController, BillWriteState>(
      BillWriteController.new,
    );
