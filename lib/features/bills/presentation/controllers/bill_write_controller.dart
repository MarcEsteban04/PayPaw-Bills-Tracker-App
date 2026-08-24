import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../recurring/domain/entities/new_recurring_bill.dart';
import '../../../recurring/domain/repositories/recurring_bill_repository.dart';
import '../../../recurring/presentation/controllers/recurring_bill_providers.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/new_bill.dart';
import '../widgets/bill_form.dart';
import 'bill_detail_provider.dart';
import 'bill_repository_provider.dart';

/// Whether a write is in flight, and what it said if it failed.
///
/// Deliberately small. The form owns the fields — see [BillForm] — so what is
/// left here is only what has to outlive a rebuild of them.
class BillWriteState {
  const BillWriteState({
    this.isSaving = false,
    this.errorMessage,
    this.savedName,
  });

  final bool isSaving;

  /// A failure, in words safe to show.
  final String? errorMessage;

  /// The name of what was just written, set once the write succeeded. The screen
  /// watches for it and leaves.
  ///
  /// A name rather than the saved `Bill`, because the two write paths do not
  /// produce the same kind of row — a recurring save creates a template, not a
  /// bill — and the name is the only part either screen ever used.
  final String? savedName;

  BillWriteState copyWith({
    bool? isSaving,
    String? errorMessage,
    String? savedName,
    bool clearError = false,
  }) => BillWriteState(
    isSaving: isSaving ?? this.isSaving,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    savedName: savedName ?? this.savedName,
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

  /// Stores a new bill, or the schedule that will produce them.
  ///
  /// **A recurrence changes what gets written.** With one, the row goes to
  /// `recurring_bills` and the occurrences — including the first — come from the
  /// generator. Writing a bill *as well* would be a duplicate the generator then
  /// tries to create again, and only the unique index would stop it.
  Future<bool> create(BillFormValues values) {
    if (values.recurrence != null) {
      return _createRecurring(values);
    }

    return _write(
      () => ref.read(billRepositoryProvider).createBill(_draft(values)),
    );
  }

  /// Stores a template, then asks for its occurrences straight away.
  ///
  /// The generation call is what makes the bill appear now rather than after
  /// tonight's scheduled run. It is deliberately not part of the success
  /// condition: the template is saved either way, tonight's job will produce the
  /// same occurrences, and failing the save because a follow-up call timed out
  /// would lose work the user has already done.
  Future<bool> _createRecurring(BillFormValues values) async {
    if (state.isSaving) {
      return false;
    }

    final NewRecurringBill draft = _recurringDraft(values);

    if (draft.validate() case final String problem) {
      state = state.copyWith(isSaving: false, errorMessage: problem);

      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final RecurringBillRepository repository = ref.read(
        recurringBillRepositoryProvider,
      );
      await repository.createRecurringBill(draft);

      try {
        await repository.generateDueBills();
      } on Object {
        // Saved, just not materialised yet. The scheduled run will catch it.
      }

      // Both lists change: the template is new, and its occurrences are too.
      ref
        ..invalidate(recurringBillsProvider)
        ..invalidate(billGenerationProvider)
        ..invalidate(billsProvider);

      state = state.copyWith(isSaving: false, savedName: draft.name);

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

  /// Builds the template insert.
  ///
  /// The form's due date becomes the schedule's start, not an occurrence of its
  /// own: "due on the 5th, monthly on the 15th" is two answers to one question,
  /// and the rule is the one that has to win.
  NewRecurringBill _recurringDraft(BillFormValues values) => NewRecurringBill(
    name: values.name.trim(),
    amount: values.money!,
    categoryId: values.categoryId,
    payee: _orNull(values.payee),
    recurrence: values.recurrence!,
  );

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
      state = state.copyWith(isSaving: false, savedName: (await action()).name);
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
