import 'dart:typed_data';

import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/profile/domain/repositories/avatar_store.dart';

/// An in-memory [AvatarStore].
///
/// The real one is Supabase Storage, which a widget test cannot reach. What
/// matters here is the order of operations — an object uploaded before the row
/// is written, a row cleared before the object is deleted — and that a failure
/// on either side is reported rather than swallowed.
class FakeAvatarStore implements AvatarStore {
  FakeAvatarStore({this.failUpload, this.signedUrlIsNull = false});

  /// What [upload] throws, or null if it succeeds.
  AppException? failUpload;

  /// Whether a URL cannot be minted — the object is gone, or the bucket does
  /// not exist because migration 0018 has not been applied.
  bool signedUrlIsNull;

  /// Every upload, as (contentType, byte count).
  final List<(String, int)> uploads = <(String, int)>[];

  /// Every path removed.
  final List<String> removed = <String>[];

  @override
  String pathFor(String userId) => '$userId/avatar';

  @override
  Future<String> upload({
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (failUpload case final AppException exception) {
      throw exception;
    }

    uploads.add((contentType, bytes.length));

    return pathFor('user-1');
  }

  @override
  Future<void> remove(String path) async => removed.add(path);

  @override
  Future<String?> signedUrl(String path) async =>
      signedUrlIsNull ? null : 'https://example.test/$path?token=abc';
}
