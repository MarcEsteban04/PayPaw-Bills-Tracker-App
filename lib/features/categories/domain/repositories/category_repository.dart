import '../entities/category.dart';

/// Reads categories.
///
/// Read-only for now. Sprint 23 needs a list to pick from; creating and editing
/// a user's own categories is a settings screen that does not exist yet, and a
/// write method nothing calls is a method nothing tests.
abstract interface class CategoryRepository {
  /// The shared categories plus the signed-in user's own, in display order.
  ///
  /// One list rather than two, because the picker shows one list. Which rows come
  /// back is decided by the read policy, not by this method.
  Future<List<Category>> fetchCategories();
}
