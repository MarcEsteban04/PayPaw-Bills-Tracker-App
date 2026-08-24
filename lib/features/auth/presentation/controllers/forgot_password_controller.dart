import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase_auth_repository.dart';

/// Drives the forgot-password screen.
///
/// The success value is the address the link was sent to, so the confirmation
/// can name it. `null` means nothing has been submitted yet.
class ForgotPasswordController extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() => const AsyncData<String?>(null);

  /// Requests a reset email.
  ///
  /// Succeeds whether or not the address has an account — Supabase does not say,
  /// and the confirmation is worded so the app does not either.
  Future<void> submit({required String email}) async {
    if (state.isLoading) {
      return;
    }

    final String trimmed = email.trim();

    state = const AsyncLoading<String?>();
    state = await AsyncValue.guard<String?>(() async {
      await ref.read(authRepositoryProvider).sendPasswordReset(email: trimmed);

      return trimmed;
    });
  }

  /// Clears an error so the form can be retried.
  void clearError() {
    if (state.hasError) {
      state = const AsyncData<String?>(null);
    }
  }
}

/// Reset-request state for the forgot-password screen.
final NotifierProvider<ForgotPasswordController, AsyncValue<String?>>
forgotPasswordControllerProvider =
    NotifierProvider<ForgotPasswordController, AsyncValue<String?>>(
      ForgotPasswordController.new,
    );
