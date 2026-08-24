import 'package:meta/meta.dart';

/// What kind of thing a bill is.
///
/// Two kinds in one table, distinguished by [userId]: the thirteen shared rows
/// seeded by `0004_categories.sql`, which every account sees and nobody can edit,
/// and rows a user made for themselves.
///
/// Pure Dart. [iconName] is a Material icon *identifier*, not an icon — turning
/// it into one needs `package:flutter`, so that lives in the presentation layer.
@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.iconName,
    required this.sortOrder,
    this.userId,
    this.colorHex,
  });

  final String id;

  /// Null for a shared category. The one nullable ownership column in the
  /// schema, and the reason the read policy differs from the write policies.
  final String? userId;

  final String name;

  /// A Material icon identifier — `bolt`, `water_drop`. An identifier rather than
  /// an image because the app already ships the icon font, so a category list
  /// costs no network requests.
  final String iconName;

  /// `#RRGGBB`, or null to let the app choose from its palette.
  final String? colorHex;

  final int sortOrder;

  /// Whether this is one of the shared rows. Those cannot be renamed or deleted,
  /// and a UI that offers to is a UI that produces a policy violation.
  bool get isSystem => userId == null;

  @override
  bool operator ==(Object other) =>
      other is Category &&
      other.id == id &&
      other.userId == userId &&
      other.name == name &&
      other.iconName == iconName &&
      other.colorHex == colorHex &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode =>
      Object.hash(id, userId, name, iconName, colorHex, sortOrder);

  @override
  String toString() => 'Category($name${isSystem ? ', shared' : ''})';
}
