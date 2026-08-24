import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/presentation/controllers/current_user_provider.dart';
import '../../../notifications/domain/entities/reminder_time.dart';
import '../../domain/entities/account_setup.dart';
import '../../domain/repositories/account_setup_repository.dart';
import '../../domain/repositories/onboarding_progress_store.dart';
import 'onboarding_providers.dart';

/// How far through onboarding the user is, and what they have chosen so far.
///
/// The step lives here rather than in a `PageController` so the answers and the
/// position cannot disagree — a rebuild that resets one but not the other is the
/// classic wizard bug.
class OnboardingFormState {
  const OnboardingFormState({
    required this.setup,
    this.step = 0,
    this.isSaving = false,
    this.errorMessage,
  });

  /// Two steps: money and time, then reminders. Both do real work; neither is a
  /// slide about how good the app is.
  static const int stepCount = 2;

  final AccountSetup setup;
  final int step;
  final bool isSaving;
  final String? errorMessage;

  bool get isFirstStep => step == 0;
  bool get isLastStep => step == stepCount - 1;

  /// 1-based, for "Step 1 of 2".
  int get displayStep => step + 1;

  OnboardingFormState copyWith({
    AccountSetup? setup,
    int? step,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) => OnboardingFormState(
    setup: setup ?? this.setup,
    step: step ?? this.step,
    isSaving: isSaving ?? this.isSaving,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// Drives the onboarding form.
///
/// `save` and `skip` return a bool rather than leaving the screen to inspect
/// state afterwards, because the screen's only question is "may I navigate away
/// now", and an `AsyncValue` turns that one question into three cases.
class OnboardingController extends Notifier<OnboardingFormState> {
  @override
  OnboardingFormState build() {
    // Keeps the session subscription alive for as long as the form exists,
    // without making the form's state depend on it.
    //
    // `_finish` reads `currentUserProvider`, and a StreamProvider nobody is
    // listening to reports `AsyncLoading` on first read — which is
    // indistinguishable from signed out. That would refuse to save at the exact
    // moment the user pressed Finish, with a message about their session having
    // ended. It happens to work in the running app because the router's guard is
    // already watching the session; relying on another part of the app to hold a
    // subscription open is not a dependency worth having.
    //
    // `listen` rather than `watch` on purpose: watching would rebuild the
    // notifier and discard half-filled answers whenever the session object
    // changed.
    ref.listen(currentUserProvider, (_, _) {});

    return OnboardingFormState(setup: ref.watch(deviceSetupDefaultsProvider));
  }

  void next() {
    if (!state.isLastStep) {
      state = state.copyWith(step: state.step + 1, clearError: true);
    }
  }

  void back() {
    if (!state.isFirstStep) {
      state = state.copyWith(step: state.step - 1, clearError: true);
    }
  }

  void setCurrency(String currency) =>
      _update(state.setup.copyWith(currency: currency));

  void setTimeZone(String timeZone) =>
      _update(state.setup.copyWith(timeZone: timeZone));

  void setRemindersEnabled(bool enabled) =>
      _update(state.setup.copyWith(remindersEnabled: enabled));

  void setReminderTime(ReminderTime time) =>
      _update(state.setup.copyWith(reminderTime: time));

  void toggleReminderDay(int days) =>
      _update(state.setup.toggleReminderDay(days));

  /// Persists the answers and marks onboarding done for this account.
  ///
  /// Returns whether the caller may leave the screen.
  Future<bool> save() => _finish(state.setup);

  /// Leaves onboarding without changing anything, and does not ask again.
  ///
  /// Still writes. The column defaults are what "skip" means, so writing them
  /// explicitly makes a skipped account identical to a completed one that
  /// changed nothing. A skip that leaves rows missing produces a third kind of
  /// account that every later feature has to allow for.
  Future<bool> skip() => _finish(const AccountSetup());

  void _update(AccountSetup setup) =>
      state = state.copyWith(setup: setup, clearError: true);

  Future<bool> _finish(AccountSetup setup) async {
    if (state.isSaving) {
      return false;
    }

    final String? userId = ref.read(currentUserProvider).value?.id;

    if (userId == null) {
      state = state.copyWith(
        errorMessage: 'Your session ended. Sign in again to finish setting up.',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    final AccountSetupRepository repository = ref.read(
      accountSetupRepositoryProvider,
    );
    final OnboardingProgressStore progress = ref.read(
      onboardingProgressStoreProvider,
    );

    try {
      await repository.save(setup);

      // Marked only after the write succeeds. Marking first would mean a failed
      // save silently costs the user the whole step with no way back to it.
      await progress.markOnboardingCompleted(userId);

      return true;
    } on AppException catch (exception) {
      // Already carries a message written for a user.
      state = state.copyWith(
        isSaving: false,
        errorMessage: exception.userMessage,
      );
      return false;
    } on Object {
      // Anything else has no user-safe message, and its toString is not
      // something to put on screen.
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }
}

final NotifierProvider<OnboardingController, OnboardingFormState>
onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingFormState>(
      OnboardingController.new,
    );
