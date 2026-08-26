import '../../domain/entities/user_profile.dart';

/// Maps a `public.profiles` row to [UserProfile].
///
/// Column names have to match `0002_profiles.sql` exactly, and a mismatch is a
/// runtime failure rather than a compile error — which is the whole reason a
/// hand-written mapper gets its own test.
abstract final class UserProfileDto {
  static const String tableName = 'profiles';

  static const String columnId = 'id';
  static const String columnDisplayName = 'display_name';
  static const String columnAvatarUrl = 'avatar_url';
  static const String columnCurrency = 'currency';
  static const String columnLocale = 'locale';
  static const String columnTimeZone = 'time_zone';

  static const String selectColumns =
      '$columnId, $columnDisplayName, $columnAvatarUrl, '
      '$columnCurrency, $columnLocale, $columnTimeZone';

  static UserProfile toEntity(Map<String, dynamic> row) => UserProfile(
    id: row[columnId] as String? ?? '',
    // Blank is null. The column allows an empty string and a trigger could
    // write one; a name of zero characters is not a name, and letting it
    // through would show a blank line where the heading goes.
    displayName: _text(row[columnDisplayName]),
    avatarUrl: _text(row[columnAvatarUrl]),
    // The column defaults cover a row this build wrote, but not a row written
    // before the column existed. Falling back rather than throwing keeps a
    // half-migrated profile readable.
    currency: row[columnCurrency] as String? ?? 'PHP',
    locale: row[columnLocale] as String? ?? 'en_PH',
    timeZone: _text(row[columnTimeZone]) ?? 'Asia/Manila',
  );

  /// The fields a user is allowed to change, for an update.
  ///
  /// **A patch, not the whole row.** `id` is the primary key and `currency` is
  /// not offered as a setting, so sending either would be sending a value no
  /// screen collected — and an update that writes columns nobody edited is an
  /// update that can undo something another device changed.
  static Map<String, dynamic> toDisplayNameUpdate(String? name) =>
      <String, dynamic>{columnDisplayName: _text(name)};

  static Map<String, dynamic> toTimeZoneUpdate(String zone) =>
      <String, dynamic>{columnTimeZone: zone};

  /// A trimmed string, or null if there is nothing left of it.
  static String? _text(Object? value) {
    if (value is! String) {
      return null;
    }

    final String trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }
}
