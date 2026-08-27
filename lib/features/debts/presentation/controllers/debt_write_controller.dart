import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/new_debt.dart';
import 'debt_providers.dart';

/// Whether a debt write is in flight, and what it said if it failed.
class DebtWriteState {
  const DebtWriteState({this.isSaving = false, this.errorMessage});

  final bool isSaving;

  /// A failure, in words safe to show.
  final String? errorMessage;

  DebtWriteState copyWith({
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) => DebtWriteState(
    isSaving: isSaving ?? this.isSaving,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// Creating, changing, settling and removing debts.
///
/// ## Every write invalidates the list and the row
///
/// Nothing stores what is left on a debt — `debt_status` derives it by summing
/// payments — so after any write the app's idea of a debt is stale in two places
/// at once, and patching either by hand would be guessing at what the view is
/// about to say.
///
/// Repayments are *not* written here. They go through `PaymentWriteController`,
/// which already knows how to record money moving and which invalidates these
/// same providers when the target is a debt. A second path to the payments table
/// would be a second set of rules about what a payment is.
class DebtWriteController extends Notifier<DebtWriteState> {
  @override
  DebtWriteState build() => const DebtWriteState();

  void clearError() => state = state.copyWith(clearError: true);

  /// Creates one. Returns it, or null if the write failed.
  Future<Debt?> create(NewDebt draft) =>
      _write(() => ref.read(debtRepositoryProvider).createDebt(draft));

  /// Saves a change to an existing one.
  Future<Debt?> update(Debt debt) =>
      _write(() => ref.read(debtRepositoryProvider).updateDebt(debt));

  /// Marks it repaid.
  ///
  /// Deliberately available whatever the arithmetic says. `debt_status` reports
  /// whether the payments sum to the principal, and this is the user overruling
  /// it in either direction — the last hundred pesos waved off, or a debt kept
  /// open because something is still owed that PayPaw does not know about.
  Future<Debt?> settle(String id) =>
      _write(() => ref.read(debtRepositoryProvider).settleDebt(id));

  /// Marks it open again, for a settlement recorded by mistake.
  Future<Debt?> reopen(String id) =>
      _write(() => ref.read(debtRepositoryProvider).reopenDebt(id));

  /// Removes it entirely. True if it landed.
  ///
  /// The database refuses this once a repayment references the debt. That is the
  /// intended behaviour rather than a limitation, and the screen says so before
  /// asking.
  Future<bool> delete(String id) async {
    final Object? result = await _write<Object>(() async {
      await ref.read(debtRepositoryProvider).deleteDebt(id);

      return const Object();
    });

    return result != null;
  }

  Future<T?> _write<T>(Future<T> Function() action) async {
    if (state.isSaving) {
      return null;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final T result = await action();

      ref.invalidate(debtsProvider);

      state = state.copyWith(isSaving: false);
      return result;
    } on AppException catch (exception) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: exception.userMessage,
      );
      return null;
    } on Object {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
      return null;
    }
  }
}

final NotifierProvider<DebtWriteController, DebtWriteState>
debtWriteControllerProvider =
    NotifierProvider<DebtWriteController, DebtWriteState>(
      DebtWriteController.new,
    );
