import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../bills/presentation/controllers/bill_detail_provider.dart';
import '../../../recurring/domain/entities/recurring_bill.dart';
import '../../../recurring/presentation/controllers/recurring_bill_providers.dart';
import '../../domain/entities/new_subscription.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_details.dart';
import 'subscription_providers.dart';

/// Whether a subscription write is in flight, and what it said if it failed.
class SubscriptionWriteState {
  const SubscriptionWriteState({this.isSaving = false, this.errorMessage});

  final bool isSaving;

  /// A failure, in words safe to show.
  final String? errorMessage;

  SubscriptionWriteState copyWith({
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) => SubscriptionWriteState(
    isSaving: isSaving ?? this.isSaving,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// Creating, changing and cancelling subscriptions.
///
/// ## Every write invalidates the bills too
///
/// A subscription is a recurring template, and templates generate bills. Adding
/// one means new bills exist the moment the generator next runs; deleting one
/// changes what the dashboard's monthly commitment says. Leaving `billsProvider`
/// alone would show a subscription list that disagreed with the home screen
/// until something else happened to refresh it.
class SubscriptionWriteController extends Notifier<SubscriptionWriteState> {
  @override
  SubscriptionWriteState build() => const SubscriptionWriteState();

  /// Creates one. Returns it, or null if the write failed.
  Future<Subscription?> create(NewSubscription draft) => _write(
    () => ref.read(subscriptionRepositoryProvider).createSubscription(draft),
  );

  /// Saves both halves of an edit as one action.
  ///
  /// One `_write` rather than two calls, because two would report two errors for
  /// one save and — worse — the second would be refused outright by the
  /// in-flight guard if a caller ever stopped awaiting the first.
  ///
  /// **The schedule goes first.** If the second write fails the user is told the
  /// save failed and the form stays open on what they typed, so retrying
  /// finishes the job. That is the mild half of the split: unlike a create, both
  /// rows already exist, so a failure here leaves a subscription that is intact
  /// and merely half-updated rather than one that is invisible.
  Future<Subscription?> update({
    required RecurringBill template,
    required SubscriptionDetails details,
  }) => _write(() async {
    // Through the recurring repository, because it is the same edit for a
    // subscription as for any other repeating bill and two paths to it would be
    // two chances to disagree.
    final RecurringBill saved = await ref
        .read(recurringBillRepositoryProvider)
        .updateRecurringBill(template);

    final SubscriptionDetails savedDetails = await ref
        .read(subscriptionRepositoryProvider)
        .updateDetails(details);

    return Subscription(template: saved, details: savedDetails);
  });

  /// Saves the schedule half on its own: name, amount, how often, when next.
  Future<RecurringBill?> _saveSchedule(RecurringBill template) => _write(
    () =>
        ref.read(recurringBillRepositoryProvider).updateRecurringBill(template),
  );

  /// Stops it and forgets it. True if it landed.
  ///
  /// The bills it already generated survive as ordinary bills — cancelling is
  /// "stop charging me", not "those months never happened".
  Future<bool> delete(String id) async {
    final Object? result = await _write<Object>(() async {
      await ref.read(subscriptionRepositoryProvider).deleteSubscription(id);

      return const Object();
    });

    return result != null;
  }

  /// Pauses or resumes without deleting.
  ///
  /// A paused subscription still exists and still shows in the list — it is a
  /// record of a decision. What changes is that it stops generating bills and
  /// stops counting toward the monthly commitment.
  Future<RecurringBill?> setActive(
    RecurringBill template, {
    required bool isActive,
  }) => _saveSchedule(template.copyWith(isActive: isActive));

  Future<T?> _write<T>(Future<T> Function() action) async {
    if (state.isSaving) {
      return null;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final T result = await action();

      ref
        ..invalidate(subscriptionsProvider)
        ..invalidate(recurringBillsProvider)
        // See the note above: a subscription is a template, and templates make
        // bills.
        ..invalidate(billsProvider);

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

final NotifierProvider<SubscriptionWriteController, SubscriptionWriteState>
subscriptionWriteControllerProvider =
    NotifierProvider<SubscriptionWriteController, SubscriptionWriteState>(
      SubscriptionWriteController.new,
    );
