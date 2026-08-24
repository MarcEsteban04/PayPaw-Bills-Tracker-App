import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_error_mapper.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_with_status.dart';
import '../../domain/entities/new_bill.dart';
import '../../domain/repositories/bill_repository.dart';
import '../dtos/bill_dto.dart';
import '../dtos/bill_with_status_dto.dart';

/// [BillRepository] over Supabase.
///
/// No data source class. Every method here is one PostgREST call plus a mapping,
/// so a data source would be a layer whose only job is to be a layer — see the
/// decision table in `docs/architecture.md`. This stays the only file in the
/// feature that imports `supabase_flutter`.
///
/// ## Reads come from the view, writes go to the table
///
/// `bill_status` carries the derived status and payment totals a screen needs, in
/// one round trip. `bills` is the only thing there is to write. Both are covered
/// by RLS — the view is `security_invoker`, so it runs as the caller rather than
/// as its definer, which is the single thing standing between a view over `bills`
/// and one that cheerfully returns everybody's.
///
/// ## Writes never filter on `user_id`
///
/// `.eq('id', id)` is enough. The RLS policy already restricts every statement to
/// rows where `user_id = auth.uid()`, so adding the filter would express the same
/// constraint a second time in a place that can drift from the policy. It would
/// also read as though it were doing the securing, which is exactly the
/// misunderstanding to avoid: **the policy secures this, not the query.**
class SupabaseBillRepository implements BillRepository {
  const SupabaseBillRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BillWithStatus>> fetchBills({
    bool includeArchived = false,
  }) async {
    return _guard(() async {
      // The filter builder has to be built up before ordering: PostgrestFilterBuilder
      // becomes a PostgrestTransformBuilder once `order` is applied, and no filter
      // can be added after that.
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _client
          .from(BillWithStatusDto.viewName)
          .select(BillWithStatusDto.selectColumns);

      if (!includeArchived) {
        query = query.isFilter(BillDto.columnArchivedAt, null);
      }

      final List<Map<String, dynamic>> rows = await query
          // Soonest due first: the question a bills list exists to answer is
          // "what is next", and any other default order makes the user sort it.
          //
          // `ascending: true` is not redundant. postgrest-dart's `order` defaults
          // to *descending*, so leaving it off silently sorted the list latest
          // first — furthest-away bills at the top, the overdue ones buried at
          // the bottom. It was caught by a test asserting the query string, which
          // is the only place that mistake is visible.
          .order(BillDto.columnDueOn, ascending: true)
          // Tie-break by name so two bills due the same day keep a stable order
          // between fetches. Without it the order is whatever Postgres returns,
          // which can change and reads as the list shuffling itself.
          .order(BillDto.columnName, ascending: true);

      return rows.map(BillWithStatusDto.toEntity).toList();
    });
  }

  @override
  Future<BillWithStatus?> fetchBill(String id) async {
    return _guard(() async {
      // maybeSingle, not single: a missing row is a null, not an exception. Under
      // RLS "deleted" and "belongs to someone else" are the same answer, and they
      // have to stay the same answer — reporting them differently would confirm
      // that a stranger's bill exists.
      final Map<String, dynamic>? row = await _client
          .from(BillWithStatusDto.viewName)
          .select(BillWithStatusDto.selectColumns)
          .eq(BillWithStatusDto.columnBillId, id)
          .maybeSingle();

      return row == null ? null : BillWithStatusDto.toEntity(row);
    });
  }

  @override
  Future<Bill> createBill(NewBill draft) async {
    final String userId = _requireUserId('createBill');

    return _guard(() async {
      // select().single() so the insert returns the stored row: the caller needs
      // the id the database assigned, and re-fetching to find it is a second round
      // trip for something the first one can return.
      final Map<String, dynamic> row = await _client
          .from(_table)
          .insert(BillDto.toInsert(draft, userId: userId))
          .select(BillDto.selectColumns)
          .single();

      return BillDto.toEntity(row);
    });
  }

  @override
  Future<Bill> updateBill(Bill bill) =>
      _update(bill.id, BillDto.toUpdate(bill));

  @override
  Future<Bill> archiveBill(String id) => _update(id, <String, dynamic>{
    // Stamped by the client because Postgres' `now()` is not reachable through
    // PostgREST without an RPC, and a dedicated function for one timestamp is
    // more moving parts than the problem deserves. A device clock minutes out is
    // harmless here: nothing computes against this value, it only records that
    // the bill was put away.
    BillDto.columnArchivedAt: DateTime.now().toUtc().toIso8601String(),
  });

  @override
  Future<Bill> unarchiveBill(String id) =>
      _update(id, <String, dynamic>{BillDto.columnArchivedAt: null});

  @override
  Future<void> deleteBill(String id) async {
    return _guard(() async {
      await _client.from(_table).delete().eq(BillDto.columnId, id);
    });
  }

  static const String _table = 'bills';

  /// One update path, so every write returns the stored row the same way.
  Future<Bill> _update(String id, Map<String, dynamic> values) async {
    // Checked even though the update does not send a user_id: without a session
    // the request goes out anonymous and RLS matches nothing, which succeeds
    // while changing zero rows. Failing here says what actually happened.
    _requireUserId('updateBill');

    return _guard(() async {
      final Map<String, dynamic> row = await _client
          .from(_table)
          .update(values)
          .eq(BillDto.columnId, id)
          // single(), so an update that matched nothing is an error rather than a
          // silent success. Under RLS a non-matching id and someone else's bill
          // are the same case, and both should fail loudly to the caller — which
          // is different from `fetchBill`, where the *user* is told nothing.
          .select(BillDto.selectColumns)
          .single();

      return BillDto.toEntity(row);
    });
  }

  String _requireUserId(String operation) {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw AuthenticationException(
        message: 'Your session ended. Sign in again to continue.',
        debugMessage: 'SupabaseBillRepository.$operation without a session',
      );
    }

    return userId;
  }

  /// Runs [body], converting anything it throws into an `AppException`.
  ///
  /// Wrapped here rather than in each method so no method can forget. The
  /// `FormatException` case matters as much as the Supabase ones: a row the DTO
  /// cannot read is a real failure, and letting it escape as a raw
  /// `FormatException` would leak a parser error into a UI that only knows how to
  /// show an `AppException`.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ServerException(
          debugMessage: 'Unreadable bill row: $error',
          cause: error,
        ),
        stackTrace,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapSupabaseError(error), stackTrace);
    }
  }
}
