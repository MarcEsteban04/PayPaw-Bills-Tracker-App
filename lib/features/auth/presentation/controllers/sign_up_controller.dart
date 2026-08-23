import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/entities/sign_up_outcome.dart';

/// Drives the registration screen.
///
/// State is an `AsyncValue` because that is already the app's error channel —
/// see `docs/architecture.md`. `null` data means "nothing submitted yet", which
/// is what distinguishes a fresh form from a completed one.
class SignUpController extends Notifier<AsyncValue<SignUpOutcome?>> {
  @override
  AsyncValue<SignUpOutcome?> build() => const AsyncData<SignUpOutcome?>(null);

  /// Creates the account.
  ///
  /// Ignores a second call while one is in flight. The button also disables
  /// itself, but the guard belongs here too: a controller that can be driven
  /// into creating two accounts because of a double tap is a controller bug, not
  /// a button bug.
  Future<void> submit({required String email, required String password}) async {
    if (state.isLoading) {
      return;
    }

    state = const AsyncLoading<SignUpOutcome?>();
    state = await AsyncValue.guard<SignUpOutcome?>(
      () => ref
          .read(authRepositoryProvider)
          .signUp(email: email, password: password),
    );
  }

  /// Clears an error so the form can be retried.
  void clearError() {
    if (state.hasError) {
      state = const AsyncData<SignUpOutcome?>(null);
    }
  }
}

/// Registration state for the sign-up screen.
final NotifierProvider<SignUpController, AsyncValue<SignUpOutcome?>>
signUpControllerProvider =
    NotifierProvider<SignUpController, AsyncValue<SignUpOutcome?>>(
      SignUpController.new,
    );
