import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/money.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/new_bill.dart';
import '../../domain/validation/bill_validators.dart';
import 'bill_repository_provider.dart';

/// What the add-bill form has collected, and what happened when it was sent.
class AddBillState {
  const AddBillState({
    this.categoryId,
    this.dueOn,
    this.isSaving = false,
    this.errorMessage,
    this.saved,
  });

  /// Null until the user picks one. Optional on purpose: the column is nullable,
  /// and forcing a category on a bill someone is trying to record quickly is a
  /// good way to have them not record it.
  final String? categoryId;

  /// Null until picked. Held here rather than in a `TextEditingController`
  /// because a date is not text — the field shows it, the picker sets it, and
  /// there is no state in which a half-typed date is meaningful.
  final DateTime? dueOn;

  final bool isSaving;

  /// A failure from the backend, in words safe to show.
  final String? errorMessage;

  /// Set once the insert succeeded. The screen watches for it and leaves.
  final Bill? saved;

  AddBillState copyWith({
    String? categoryId,
    DateTime? dueOn,
    bool? isSaving,
    String? errorMessage,
    Bill? saved,
    bool clearCategory = false,
    bool clearError = false,
  }) => AddBillState(
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    dueOn: dueOn ?? this.dueOn,
    isSaving: isSaving ?? this.isSaving,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    saved: saved ?? this.saved,
  );
}

/// Creates a bill.
///
/// The text fields are not in this state. They live in `TextEditingController`s
/// on the screen, which is where Flutter already keeps text, and mirroring them
/// here would mean two copies of the same string that have to be kept in step —
/// the classic form bug. What *is* here is everything a text field cannot hold:
/// the picked date, the picked category, and the outcome of the write.
class AddBillController extends Notifier<AddBillState> {
  @override
  AddBillState build() => const AddBillState();

  void setCategory(String? categoryId) => state = categoryId == null
      ? state.copyWith(clearCategory: true, clearError: true)
      : state.copyWith(categoryId: categoryId, clearError: true);

  void setDueOn(DateTime date) =>
      // Normalised to midnight local. A bill is due on a day, and a time
      // smuggled in from a picker is a value that formats differently depending
      // on where the device is.
      state = state.copyWith(
        dueOn: DateTime(date.year, date.month, date.day),
        clearError: true,
      );

  void clearError() => state = state.copyWith(clearError: true);

  /// Sends the bill. Returns whether it was stored.
  ///
  /// Takes the text as arguments rather than reading it from state, for the
  /// reason in the class comment. `amount` arrives as the raw string the user
  /// typed so that parsing happens in exactly one place — [Money.tryParse] —
  /// rather than once here and once in the validator.
  Future<bool> submit({
    required String name,
    required String amount,
    String? payee,
    String? notes,
  }) async {
    if (state.isSaving) {
      return false;
    }

    final DateTime? dueOn = state.dueOn;
    final Money? parsed = Money.tryParse(amount);

    if (dueOn == null || parsed == null) {
      // Unreachable through the form, which validates first. Guarded anyway,
      // because the alternative is a null assertion in a submit handler.
      state = state.copyWith(
        errorMessage: 'Check the amount and the due date, then try again.',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final Bill bill = await ref
          .read(billRepositoryProvider)
          .createBill(
            NewBill(
              name: name.trim(),
              amount: parsed,
              dueOn: dueOn,
              categoryId: state.categoryId,
              // Empty is not the same as absent. A blank field means "no payee",
              // which is a null column, not an empty string that later formats
              // as a stray blank line on the detail screen.
              payee: _orNull(payee),
              notes: _orNull(notes),
            ),
          );

      state = state.copyWith(isSaving: false, saved: bill);
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

  /// Whether the form would pass validation, for enabling the submit button.
  ///
  /// Shares [BillValidators] with the fields rather than restating the rules, so
  /// a button cannot be enabled for a form that then refuses to submit.
  bool isComplete({
    required String name,
    required String amount,
    required DateTime today,
    String? payee,
    String? notes,
  }) => BillValidators.isComplete(
    name: name,
    amount: amount,
    dueOn: state.dueOn,
    today: today,
    payee: payee,
    notes: notes,
  );

  static String? _orNull(String? value) {
    final String trimmed = (value ?? '').trim();

    return trimmed.isEmpty ? null : trimmed;
  }
}

final NotifierProvider<AddBillController, AddBillState>
addBillControllerProvider = NotifierProvider<AddBillController, AddBillState>(
  AddBillController.new,
);
