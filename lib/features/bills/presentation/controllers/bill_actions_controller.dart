import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import 'bill_detail_provider.dart';
import 'bill_repository_provider.dart';

/// The outcome of archiving, restoring or deleting a bill.
class BillActionState {
  const BillActionState({this.isBusy = false, this.errorMessage});

  final bool isBusy;

  /// A failure, in words safe to show.
  final String? errorMessage;

  BillActionState copyWith({
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) => BillActionState(
    isBusy: isBusy ?? this.isBusy,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// Archives, restores and deletes bills.
///
/// Separate from `BillWriteController`, which saves forms. These three take an id
/// and return nothing the caller has to render, so sharing that controller's
/// `saved` bill would mean a field that is meaningless for half its methods.
///
/// Each one invalidates the list, and the row it touched, rather than patching a
/// cache: the view computes the status and the totals, and only the database knows
/// what they are afterwards.
class BillActionsController extends Notifier<BillActionState> {
  @override
  BillActionState build() => const BillActionState();

  void clearError() => state = state.copyWith(clearError: true);

  /// Puts a bill away. Reversible, and the normal way one leaves a list.
  Future<bool> archive(String id) =>
      _run(id, () => ref.read(billRepositoryProvider).archiveBill(id));

  /// Brings an archived bill back.
  Future<bool> restore(String id) =>
      _run(id, () => ref.read(billRepositoryProvider).unarchiveBill(id));

  /// Destroys a bill and everything referencing it.
  ///
  /// Not reversible, and not undoable — which is why the UI confirms first rather
  /// than offering an undo afterwards. A snackbar with an Undo button on an
  /// operation that cannot be undone is a lie.
  Future<bool> delete(String id) =>
      _run(id, () => ref.read(billRepositoryProvider).deleteBill(id));

  Future<bool> _run(String id, Future<void> Function() action) async {
    if (state.isBusy) {
      return false;
    }

    state = state.copyWith(isBusy: true, clearError: true);

    try {
      await action();

      ref.invalidate(billsProvider);
      ref.invalidate(billDetailProvider(id));

      state = state.copyWith(isBusy: false);
      return true;
    } on AppException catch (exception) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: exception.userMessage,
      );
      return false;
    } on Object {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }
}

final NotifierProvider<BillActionsController, BillActionState>
billActionsControllerProvider =
    NotifierProvider<BillActionsController, BillActionState>(
      BillActionsController.new,
    );
