import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase_auth_repository.dart';

/// Ends the session.
///
/// `AsyncValue<void>` because the only thing a caller needs is whether it is in
/// flight and whether it failed. Success shows itself: the session stream emits
/// null and every guard reacts.
class SignOutController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData<void>(null);

  Future<void> signOut() async {
    if (state.isLoading) {
      return;
    }

    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(
      () => ref.read(authRepositoryProvider).signOut(),
    );
  }
}

/// Sign-out state, for the button's busy indicator.
final NotifierProvider<SignOutController, AsyncValue<void>>
signOutControllerProvider =
    NotifierProvider<SignOutController, AsyncValue<void>>(
      SignOutController.new,
    );
