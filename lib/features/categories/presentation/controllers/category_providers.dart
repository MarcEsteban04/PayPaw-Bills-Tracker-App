import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../data/repositories/supabase_category_repository.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';

final Provider<CategoryRepository> categoryRepositoryProvider =
    Provider<CategoryRepository>(
      (Ref ref) =>
          SupabaseCategoryRepository(ref.watch(supabaseClientProvider)),
    );

/// The categories available to the signed-in user.
///
/// Kept alive rather than fetched per screen: the list is thirteen shared rows
/// plus a handful of the user's own, it changes rarely, and every bill form and
/// filter needs it. Refetching on each open would be a spinner on a picker.
final FutureProvider<List<Category>> categoriesProvider =
    FutureProvider<List<Category>>(
      (Ref ref) => ref.watch(categoryRepositoryProvider).fetchCategories(),
    );
