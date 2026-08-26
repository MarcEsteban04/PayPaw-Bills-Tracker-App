import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../auth/presentation/controllers/current_user_provider.dart';
import '../../data/repositories/supabase_avatar_store.dart';
import '../../data/repositories/supabase_profile_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/avatar_store.dart';
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

final Provider<AvatarStore> avatarStoreProvider = Provider<AvatarStore>(
  (Ref ref) => SupabaseAvatarStore(ref.watch(supabaseClientProvider)),
);

/// A URL that can actually load this account's picture, or null if there is none.
///
/// The bucket is private, so what the column holds is a path and this is where
/// it becomes something an `Image` can fetch. Invalidated on every upload, which
/// is what makes a replaced picture appear rather than being served from the old
/// URL's cache entry.
final FutureProvider<String?> avatarUrlProvider = FutureProvider<String?>((
  Ref ref,
) async {
  final String? path = ref.watch(userProfileProvider).value?.avatarUrl;

  if (path == null) {
    return null;
  }

  return ref.watch(avatarStoreProvider).signedUrl(path);
});

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

  /// Uploads a picture and records where it went. True if it landed.
  ///
  /// The object first, the column second. The other order would leave a row
  /// pointing at a picture that does not exist — which reads as a broken avatar
  /// rather than as no avatar, and there is nothing the user could do about it.
  Future<bool> saveAvatar({
    required Uint8List bytes,
    required String contentType,
  }) => _write(() async {
    final String path = await ref
        .read(avatarStoreProvider)
        .upload(bytes: bytes, contentType: contentType);

    await ref.read(profileRepositoryProvider).saveAvatarPath(path);
  });

  /// Removes the picture. True if it landed.
  ///
  /// The column first this time, then the object. If the delete fails the row
  /// already says there is no picture, which is the state the user asked for —
  /// the leftover object is invisible and the next upload overwrites it.
  Future<bool> removeAvatar() => _write(() async {
    final String? path = ref.read(userProfileProvider).value?.avatarUrl;

    await ref.read(profileRepositoryProvider).saveAvatarPath(null);

    if (path != null) {
      await ref.read(avatarStoreProvider).remove(path);
    }
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
