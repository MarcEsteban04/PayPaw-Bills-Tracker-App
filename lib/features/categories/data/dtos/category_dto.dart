import '../../domain/entities/category.dart';

/// Maps a `public.categories` row to [Category].
///
/// Read-only, like the repository. Column names are compared against
/// `supabase/migrations/0004_categories.sql` by eye, and a test asserts each one
/// appears in that file.
abstract final class CategoryDto {
  static const String tableName = 'categories';

  static const String columnId = 'id';
  static const String columnUserId = 'user_id';
  static const String columnName = 'name';
  static const String columnIconName = 'icon_name';
  static const String columnColorHex = 'color_hex';
  static const String columnSortOrder = 'sort_order';

  /// Explicit rather than `*`, so adding a column to the table does not silently
  /// change what the app fetches over the wire.
  static const String selectColumns =
      '$columnId, $columnUserId, $columnName, $columnIconName, '
      '$columnColorHex, $columnSortOrder';

  /// Reads a row. Throws [FormatException] on one that cannot be a category.
  static Category toEntity(Map<String, dynamic> row) {
    return Category(
      id: _requireString(row, columnId),
      // Null is meaningful here rather than missing: it marks a shared row.
      userId: row[columnUserId] as String?,
      name: _requireString(row, columnName),
      iconName: _requireString(row, columnIconName),
      colorHex: row[columnColorHex] as String?,
      // Defaulted rather than required. The column has a default, so a row
      // without it is possible, and an unordered category is a cosmetic problem
      // rather than a reason to fail the whole list.
      sortOrder: switch (row[columnSortOrder]) {
        final int value => value,
        final String value => int.tryParse(value) ?? 0,
        _ => 0,
      },
    );
  }

  static String _requireString(Map<String, dynamic> row, String column) {
    final Object? value = row[column];
    if (value is String && value.isNotEmpty) {
      return value;
    }

    throw FormatException('categories.$column missing or not a string: $value');
  }
}
