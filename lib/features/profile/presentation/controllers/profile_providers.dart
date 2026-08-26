import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../auth/presentation/controllers/current_user_provider.dart';
import '../../data/repositories/supabase_profile_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>(
      (Ref ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
    );

/// The signed-in account's profile.
///
/// Keyed on the session, so signing in as somebody else on a shared phone does
/// not greet the new user by the previous one's name. Signed out it is null
/// rather than an error: there is no profile to fetch and every screen above
/// this already copes with not having one.
final FutureProvider<UserProfile?> userProfileProvider =
    FutureProvider<UserProfile?>((Ref ref) async {
      if (ref.watch(currentUserProvider).value == null) {
        return null;
      }

      return ref.watch(profileRepositoryProvider).fetch();
    });

/// The name to greet this person by, or null to fall back to their address.
///
/// A tiny provider of its own because two screens ask the same question — the
/// dashboard header and the profile header — and the fallback rule has to be
/// the same in both. Reading it as `.value` rather than awaiting keeps a slow
/// profile fetch from holding up a greeting that has a perfectly good default.
final Provider<String?> displayNameProvider = Provider<String?>(
  (Ref ref) => ref.watch(userProfileProvider).value?.name,
);

/// Whether a profile write is in flight, and what it said if it failed.
class ProfileEditState {
  const ProfileEditState({this.isSaving = false, this.errorMessage});

  final bool isSaving;

  /// A failure, in words safe to show.
  final String? errorMessage;

  ProfileEditState copyWith({
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) => ProfileEditState(
    isSaving: isSaving ?? this.isSaving,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// Writes the parts of the profile a user is allowed to change.
///
/// ## It reports failures rather than swallowing them
///
/// Unlike the reminder rebuild, these are writes the user asked for and is
/// watching. A name that appears to save and did not is worse than an error
/// message, because the next thing they do is close the screen believing it.
class ProfileController extends Notifier<ProfileEditState> {
  @override
  ProfileEditState build() => const ProfileEditState();

  /// Sets or clears the display name. True if it landed.
  Future<bool> saveDisplayName(String? name) => _write(() async {
    await ref.read(profileRepositoryProvider).saveDisplayName(name);
  });

  /// Sets the zone this account's dates are computed in. True if it landed.
  Future<bool> saveTimeZone(String zone) => _write(() async {
    await ref.read(profileRepositoryProvider).saveTimeZone(zone);
  });

  Future<bool> _write(Future<void> Function() action) async {
    if (state.isSaving) {
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await action();

      // Re-read rather than patching the cached value. The row has an
      // `updated_at` trigger and a length check on the name, so what came back
      // is the truth and what was sent is only a request.
      ref.invalidate(userProfileProvider);

      state = state.copyWith(isSaving: false);
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

final NotifierProvider<ProfileController, ProfileEditState>
profileControllerProvider =
    NotifierProvider<ProfileController, ProfileEditState>(
      ProfileController.new,
    );
