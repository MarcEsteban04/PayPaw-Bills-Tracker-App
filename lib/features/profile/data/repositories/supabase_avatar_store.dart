import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_error_mapper.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/repositories/avatar_store.dart';

/// [AvatarStore] over Supabase Storage.
///
/// The bucket and its policies are migration 0018. Every path here starts with
/// the owner's id because that is the segment those policies match on — a path
/// built any other way is refused, which is the point.
class SupabaseAvatarStore implements AvatarStore {
  const SupabaseAvatarStore(this._client);

  final SupabaseClient _client;

  static const String bucket = 'avatars';

  /// How long a signed URL lasts.
  ///
  /// An hour, which is far longer than a session spent looking at a settings
  /// screen and short enough that a leaked URL is not a leaked photograph. The
  /// provider that mints it is invalidated on every upload, so a replaced
  /// picture is never served from a stale one.
  static const int _signedUrlSeconds = 3600;

  @override
  String pathFor(String userId) => '$userId/avatar';

  @override
  Future<String> upload({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final String path = pathFor(_requireUserId('upload'));

    return _guard(() async {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            // `upsert` because there is one object per account. Without it a
            // second upload is a duplicate-key error rather than a new picture.
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      return path;
    });
  }

  @override
  Future<void> remove(String path) async {
    return _guard(() async {
      await _client.storage.from(bucket).remove(<String>[path]);
    });
  }

  @override
  Future<String?> signedUrl(String path) async {
    try {
      return await _client.storage
          .from(bucket)
          .createSignedUrl(path, _signedUrlSeconds);
    } on Object {
      // The object is gone, or the bucket does not exist yet because migration
      // 0018 has not been applied. Either way the caller shows an initial, which
      // is what it would show without a picture at all.
      return null;
    }
  }

  String _requireUserId(String operation) {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw AuthenticationException(
        message: 'Your session ended. Sign in again to continue.',
        debugMessage: 'SupabaseAvatarStore.$operation without a session',
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
