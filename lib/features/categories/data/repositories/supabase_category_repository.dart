import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_error_mapper.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../dtos/category_dto.dart';

/// [CategoryRepository] over Supabase.
class SupabaseCategoryRepository implements CategoryRepository {
  const SupabaseCategoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Category>> fetchCategories() async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from(CategoryDto.tableName)
          .select(CategoryDto.selectColumns)
          // No filter on user_id. The read policy already returns the shared rows
          // plus the caller's own, and `user_id is null or user_id = auth.uid()`
          // is not something a query can restate without getting it wrong.
          //
          // ascending: true is not redundant — postgrest-dart's `order` defaults
          // to descending, which would put "Other" (sort_order 999) first.
          .order(CategoryDto.columnSortOrder, ascending: true)
          .order(CategoryDto.columnName, ascending: true);

      return rows.map(CategoryDto.toEntity).toList();
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ServerException(
          debugMessage: 'Unreadable category row: $error',
          cause: error,
        ),
        stackTrace,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapSupabaseError(error), stackTrace);
    }
  }
}
