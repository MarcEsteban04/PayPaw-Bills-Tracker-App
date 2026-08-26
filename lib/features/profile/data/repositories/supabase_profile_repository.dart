import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_error_mapper.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../dtos/user_profile_dto.dart';

/// [ProfileRepository] over Supabase.
///
/// Neither the read nor the writes filter on the id. The RLS policy already
/// restricts every statement to `id = auth.uid()` — **the policy secures this**,
/// and restating it here would be a second expression of the same rule, free to
/// drift from the one that matters.
class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<UserProfile> fetch() async {
    return _guard(() async {
      // `maybeSingle` so an absent row arrives as null rather than as a
      // PostgREST error, and is then reported as what it actually is.
      final Map<String, dynamic>? row = await _client
          .from(UserProfileDto.tableName)
          .select(UserProfileDto.selectColumns)
          .maybeSingle();

      if (row == null) {
        throw const NotFoundException(
          message: 'We could not find your profile. Try signing in again.',
          debugMessage:
              'public.profiles has no row for auth.uid(). The handle_new_user '
              'trigger should have created one at sign-up — see migration 0002.',
        );
      }

      return UserProfileDto.toEntity(row);
    });
  }

  @override
  Future<void> saveDisplayName(String? name) async {
    final String id = _requireUserId('saveDisplayName');

    return _guard(() async {
      await _client
          .from(UserProfileDto.tableName)
          .update(UserProfileDto.toDisplayNameUpdate(name))
          .eq(UserProfileDto.columnId, id);
    });
  }

  @override
  Future<void> saveAvatarPath(String? path) async {
    final String id = _requireUserId('saveAvatarPath');

    return _guard(() async {
      await _client
          .from(UserProfileDto.tableName)
          .update(UserProfileDto.toAvatarUpdate(path))
          .eq(UserProfileDto.columnId, id);
    });
  }

  @override
  Future<void> saveTimeZone(String zone) async {
    final String id = _requireUserId('saveTimeZone');

    return _guard(() async {
      await _client
          .from(UserProfileDto.tableName)
          .update(UserProfileDto.toTimeZoneUpdate(zone))
          .eq(UserProfileDto.columnId, id);
    });
  }

  /// The id, for the `eq` on an update.
  ///
  /// Redundant against RLS and kept anyway: an `update` with no filter is a
  /// statement whose blast radius depends entirely on a policy being right, and
  /// this file should not be the one place that assumption is load-bearing.
  String _requireUserId(String operation) {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw AuthenticationException(
        message: 'Your session ended. Sign in again to continue.',
        debugMessage: 'SupabaseProfileRepository.$operation without a session',
      );
    }

    return userId;
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapSupabaseError(error), stackTrace);
    }
  }
}
