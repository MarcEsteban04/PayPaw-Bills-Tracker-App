import 'dart:typed_data';

/// Where profile pictures live.
///
/// Separate from `ProfileRepository` because it is a different store: the
/// repository writes a row in Postgres, this writes an object in Storage, and
/// the only thing they share is the path that ends up in `profiles.avatar_url`.
///
/// ## The bucket is private, so a picture needs a signed URL
///
/// [pathFor] is what gets stored; [signedUrl] is what an `Image` can actually
/// load, and it expires. Storing the signed form would put a value in a column
/// that stops working while sitting there — see migration 0018.
abstract interface class AvatarStore {
  /// The object path for the signed-in user's picture.
  ///
  /// One object per account, so replacing a picture overwrites rather than
  /// accumulating. The owner's id is the first path segment because that is what
  /// the storage policies match on.
  String pathFor(String userId);

  /// Uploads [bytes] as the signed-in user's picture, returning its path.
  ///
  /// Replaces whatever was there. [contentType] is checked against the bucket's
  /// allowed types, and it is the only record of what the file is — the path
  /// deliberately carries no extension.
  Future<String> upload({
    required Uint8List bytes,
    required String contentType,
  });

  /// Removes the picture at [path].
  Future<void> remove(String path);

  /// A URL an image widget can load, or null if one cannot be made.
  ///
  /// Null rather than throwing: a picture that will not load should cost the
  /// picture and leave the initial in its place, not fail the screen it is on.
  Future<String?> signedUrl(String path);
}
