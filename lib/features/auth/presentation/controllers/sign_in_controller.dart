import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/entities/authenticated_user.dart';

/// Drives the sign-in screen.
///
/// Mirrors `SignUpController` on purpose: same state shape, same double-submit
/// guard, same meaning for `null` data. Two auth forms behaving differently is a
/// bug waiting to happen.
class SignInController extends Notifier<AsyncValue<AuthenticatedUser?>> {
  @override
  AsyncValue<AuthenticatedUser?> build() =>
      const AsyncData<AuthenticatedUser?>(null);

  /// Signs in.
  ///
  /// Ignores a second call while one is in flight. Duplicate sign-ins are less
  /// damaging than duplicate accounts, but a double tap that fires two requests
  /// still risks tripping the backend's rate limit and showing the user an error
  /// they did not earn.
  Future<void> submit({required String email, required String password}) async {
    if (state.isLoading) {
      return;
    }

    state = const AsyncLoading<AuthenticatedUser?>();
    state = await AsyncValue.guard<AuthenticatedUser?>(
      () => ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password),
    );
  }

  /// Clears an error so the form can be retried.
  void clearError() {
    if (state.hasError) {
      state = const AsyncData<AuthenticatedUser?>(null);
    }
  }
}

/// Sign-in state for the sign-in screen.
final NotifierProvider<SignInController, AsyncValue<AuthenticatedUser?>>
signInControllerProvider =
    NotifierProvider<SignInController, AsyncValue<AuthenticatedUser?>>(
      SignInController.new,
    );
