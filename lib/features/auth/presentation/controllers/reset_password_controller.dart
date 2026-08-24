import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/entities/authenticated_user.dart';

/// Drives the reset-password screen.
///
/// Setting a new password consumes the recovery session and leaves the user
/// signed in, so the success value is the user rather than a bare flag.
class ResetPasswordController extends Notifier<AsyncValue<AuthenticatedUser?>> {
  @override
  AsyncValue<AuthenticatedUser?> build() =>
      const AsyncData<AuthenticatedUser?>(null);

  /// Sets the new password.
  ///
  /// The double-submit guard matters more here than elsewhere: the second call
  /// would run after the first has already consumed the recovery session, so it
  /// would fail with "that link has expired" on a reset that in fact worked.
  Future<void> submit({required String password}) async {
    if (state.isLoading) {
      return;
    }

    state = const AsyncLoading<AuthenticatedUser?>();
    state = await AsyncValue.guard<AuthenticatedUser?>(
      () => ref
          .read(authRepositoryProvider)
          .updatePassword(newPassword: password),
    );
  }

  /// Clears an error so the form can be retried.
  void clearError() {
    if (state.hasError) {
      state = const AsyncData<AuthenticatedUser?>(null);
    }
  }
}

/// New-password state for the reset-password screen.
final NotifierProvider<ResetPasswordController, AsyncValue<AuthenticatedUser?>>
resetPasswordControllerProvider =
    NotifierProvider<ResetPasswordController, AsyncValue<AuthenticatedUser?>>(
      ResetPasswordController.new,
    );
