import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/money.dart';
import '../../../../core/error/app_exception.dart';
import '../../../bills/presentation/controllers/bill_detail_provider.dart';
import '../../../debts/presentation/controllers/debt_providers.dart';
import '../../domain/entities/new_payment.dart';
import '../../domain/entities/payment_target.dart';
import 'payment_providers.dart';

/// Whether a payment is being written, and what it said if it failed.
///
/// The same shape as `BillWriteState`, including the part that is easy to get
/// wrong: [recorded] is cleared at the start of every write. A screen leaves on
/// the transition from null, so a value that survived the previous save would
/// make the second one ₱500 → ₱200 rather than null → something, and nothing
/// would fire. That bug shipped once already on the bill form.
class PaymentWriteState {
  const PaymentWriteState({
    this.isSaving = false,
    this.errorMessage,
    this.recorded,
  });

  final bool isSaving;

  /// A failure, in words safe to show.
  final String? errorMessage;

  /// What was just recorded, set once the write succeeded.
  ///
  /// The amount rather than the stored `Payment`, because it is the only part the
  /// confirmation message uses — and carrying the row would tempt a caller into
  /// rendering from it instead of from the re-read bill, which is the thing that
  /// knows whether this settled anything.
  final Money? recorded;

  PaymentWriteState copyWith({
    bool? isSaving,
    String? errorMessage,
    Money? recorded,
    bool clearError = false,
    bool clearRecorded = false,
  }) => PaymentWriteState(
    isSaving: isSaving ?? this.isSaving,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    recorded: clearRecorded ? null : (recorded ?? this.recorded),
  );
}

/// Records payments.
///
/// ## What it invalidates, and why all three
///
/// Nothing stores whether a bill is paid — `bill_status` derives it by summing
/// payments — so after an insert the app's idea of the bill is stale in three
/// places at once, and patching any of them by hand would be guessing at what the
/// view is about to say:
///
/// * `billsProvider`, because the list's status, its totals and the dashboard's
///   every figure are all computed from it;
/// * `billDetailProvider(billId)`, because an open drawer is showing an
///   outstanding amount that just changed;
/// * `paymentsForBillProvider(billId)`, because the history in that drawer is
///   missing the row that was the point of all this.
class PaymentWriteController extends Notifier<PaymentWriteState> {
  @override
  PaymentWriteState build() => const PaymentWriteState();

  void clearError() => state = state.copyWith(clearError: true);

  /// Writes one payment. True if it landed.
  Future<bool> record(NewPayment draft) async {
    if (state.isSaving) {
      return false;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearRecorded: true,
    );

    try {
      await ref.read(paymentRepositoryProvider).recordPayment(draft);

      // What went stale depends on what was paid. A switch rather than a pair
      // of null checks, so a third kind of target could not be added without
      // this deciding what to refresh for it.
      switch (draft.target) {
        case BillTarget(:final String id):
          ref
            ..invalidate(billsProvider)
            ..invalidate(billDetailProvider(id))
            ..invalidate(paymentsForBillProvider(id));
        case DebtTarget(:final String id):
          ref
            ..invalidate(debtsProvider)
            ..invalidate(debtProvider(id))
            ..invalidate(paymentsForDebtProvider(id));
      }

      state = state.copyWith(isSaving: false, recorded: draft.amount);
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
}

final NotifierProvider<PaymentWriteController, PaymentWriteState>
paymentWriteControllerProvider =
    NotifierProvider<PaymentWriteController, PaymentWriteState>(
      PaymentWriteController.new,
    );
