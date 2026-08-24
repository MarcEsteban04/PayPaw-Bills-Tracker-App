import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_error_mapper.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/entities/new_recurring_bill.dart';
import '../../domain/entities/recurring_bill.dart';
import '../../domain/repositories/recurring_bill_repository.dart';
import '../dtos/recurring_bill_dto.dart';

/// [RecurringBillRepository] over Supabase.
///
/// No data source class, for the same reason the other repositories have none:
/// every method is one PostgREST call plus a mapping. This stays the only file in
/// the feature that imports `supabase_flutter`.
///
/// Writes never filter on `user_id`. The RLS policy already restricts every
/// statement to `user_id = auth.uid()`. **The policy secures this, not the query.**
class SupabaseRecurringBillRepository implements RecurringBillRepository {
  const SupabaseRecurringBillRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'recurring_bills';

  /// The database function that does the generating. See migration 0016.
  static const String _generateFunction = 'generate_my_recurring_bills';

  @override
  Future<List<RecurringBill>> fetchRecurringBills({
    bool includeInactive = true,
  }) async {
    return _guard(() async {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _client
          .from(_table)
          .select(RecurringBillDto.selectColumns);

      if (!includeInactive) {
        query = query.eq(RecurringBillDto.columnIsActive, true);
      }

      final List<Map<String, dynamic>> rows = await query
          // `ascending: true` spelled out: postgrest-dart's `order` defaults to
          // descending, which sorted the bills list backwards once already.
          .order(RecurringBillDto.columnNextDueOn, ascending: true)
          .order(RecurringBillDto.columnName, ascending: true);

      return rows.map(RecurringBillDto.toEntity).toList();
    });
  }

  @override
  Future<RecurringBill?> fetchRecurringBill(String id) async {
    return _guard(() async {
      final Map<String, dynamic>? row = await _client
          .from(_table)
          .select(RecurringBillDto.selectColumns)
          .eq(RecurringBillDto.columnId, id)
          // maybeSingle, not single: a missing row is a null, not an exception.
          .maybeSingle();

      return row == null ? null : RecurringBillDto.toEntity(row);
    });
  }

  @override
  Future<RecurringBill> createRecurringBill(NewRecurringBill draft) async {
    final String userId = _requireUserId('createRecurringBill');

    return _guard(() async {
      final Map<String, dynamic> row = await _client
          .from(_table)
          .insert(RecurringBillDto.toInsert(draft, userId: userId))
          .select(RecurringBillDto.selectColumns)
          .single();

      return RecurringBillDto.toEntity(row);
    });
  }

  @override
  Future<RecurringBill> updateRecurringBill(RecurringBill bill) async {
    _requireUserId('updateRecurringBill');

    return _guard(() async {
      final Map<String, dynamic> row = await _client
          .from(_table)
          .update(RecurringBillDto.toUpdate(bill))
          .eq(RecurringBillDto.columnId, bill.id)
          // single(), so an update that matched nothing is an error rather than a
          // silent success.
          .select(RecurringBillDto.selectColumns)
          .single();

      return RecurringBillDto.toEntity(row);
    });
  }

  @override
  Future<void> deleteRecurringBill(String id) async {
    return _guard(() async {
      await _client.from(_table).delete().eq(RecurringBillDto.columnId, id);
    });
  }

  @override
  Future<int> generateDueBills() async {
    return _guard(() async {
      // The `_my_` form, which pins generation to auth.uid(). The unrestricted
      // one is revoked from `authenticated` and belongs to the scheduler.
      final Object? created = await _client.rpc<Object?>(_generateFunction);

      // The function returns an int. Anything else means the migration has not
      // been applied or was replaced, and reporting zero would look like "nothing
      // was due" rather than "this did not run".
      if (created is int) {
        return created;
      }
      if (created is String) {
        return int.tryParse(created) ?? 0;
      }

      throw ServerException(
        debugMessage:
            '$_generateFunction returned ${created.runtimeType}, not an int. '
            'Is migration 0016 applied?',
      );
    });
  }

  String _requireUserId(String operation) {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw AuthenticationException(
        message: 'Your session ended. Sign in again to continue.',
        debugMessage:
            'SupabaseRecurringBillRepository.$operation without a session',
      );
    }

    return userId;
  }

  /// Runs [body], converting anything it throws into an `AppException`.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ServerException(
          debugMessage: 'Unreadable recurring bill row: $error',
          cause: error,
        ),
        stackTrace,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapSupabaseError(error), stackTrace);
    }
  }
}
