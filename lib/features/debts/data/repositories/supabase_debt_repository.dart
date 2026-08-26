import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_error_mapper.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/debt_direction.dart';
import '../../domain/entities/new_debt.dart';
import '../../domain/repositories/debt_repository.dart';
import '../dtos/debt_dto.dart';

/// [DebtRepository] over Supabase.
///
/// No data source class. Every method here is one PostgREST call plus a mapping,
/// so a data source would be a layer whose only job is to be a layer — see the
/// decision table in `docs/architecture.md`. This stays the only file in the
/// feature that imports `supabase_flutter`.
///
/// ## Writes never filter on `user_id`
///
/// `.eq('id', id)` is enough. The RLS policy already restricts every statement to
/// rows where `user_id = auth.uid()`, so adding the filter would express the same
/// constraint a second time in a place that can drift from the policy — and it
/// would read as though it were doing the securing. **The policy secures this,
/// not the query.**
class SupabaseDebtRepository implements DebtRepository {
  const SupabaseDebtRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Debt>> fetchDebts({
    DebtDirection? direction,
    bool includeSettled = false,
  }) async {
    return _guard(() async {
      // The filter builder has to be built up before ordering: a
      // PostgrestFilterBuilder becomes a PostgrestTransformBuilder once `order`
      // is applied, and no filter can be added after that.
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _client
          .from(DebtDto.table)
          .select(DebtDto.selectColumns);

      if (direction != null) {
        query = query.eq(DebtDto.columnDirection, direction.wireValue);
      }

      if (!includeSettled) {
        query = query.isFilter(DebtDto.columnSettledAt, null);
      }

      final List<Map<String, dynamic>> rows = await query
          // Soonest agreed date first, with the undated ones last.
          //
          // `nullsFirst: false` is the whole point of this line. Postgres sorts
          // nulls last in an ascending order by default, but postgrest-dart
          // sends `nullsfirst` unless told otherwise — and a debt nobody agreed
          // a date for would then sit above every debt that has one, burying the
          // deadlines under the things with no deadline at all.
          .order(DebtDto.columnDueOn, ascending: true, nullsFirst: false)
          // Then oldest first: between two debts with no agreed date, the one
          // that has been outstanding longest is the one worth looking at.
          .order(DebtDto.columnIncurredOn, ascending: true)
          // Tie-break by name so two debts from the same day keep a stable order
          // between fetches. Without it the order is whatever Postgres returns,
          // which can change and reads as the list shuffling itself.
          .order(DebtDto.columnCounterpartyName, ascending: true);

      return rows.map(DebtDto.toEntity).toList();
    });
  }

  @override
  Future<Debt?> fetchDebt(String id) async {
    return _guard(() async {
      // maybeSingle, not single: a missing row is a null, not an exception.
      // Under RLS "deleted" and "belongs to someone else" are the same answer,
      // and they have to stay the same answer — reporting them differently would
      // confirm that a stranger's debt exists.
      final Map<String, dynamic>? row = await _client
          .from(DebtDto.table)
          .select(DebtDto.selectColumns)
          .eq(DebtDto.columnId, id)
          .maybeSingle();

      return row == null ? null : DebtDto.toEntity(row);
    });
  }

  @override
  Future<Debt> createDebt(NewDebt draft) async {
    final String userId = _requireUserId('createDebt');

    // Checked before the round trip. The column constraints would catch most of
    // this, but a Postgres check violation surfaces as a message no user can act
    // on — and `direction` in particular has no constraint that catches a
    // sensible-looking draft aimed the wrong way.
    if (draft.validate() case final String problem) {
      throw ValidationException(
        message: problem,
        debugMessage: 'SupabaseDebtRepository.createDebt rejected a draft',
      );
    }

    return _guard(() async {
      // select().single() so the insert returns the stored row: the caller needs
      // the id the database assigned, and re-fetching to find it is a second
      // round trip for something the first one can return.
      final Map<String, dynamic> row = await _client
          .from(DebtDto.table)
          .insert(DebtDto.toInsert(draft, userId: userId))
          .select(DebtDto.selectColumns)
          .single();

      return DebtDto.toEntity(row);
    });
  }

  @override
  Future<Debt> updateDebt(Debt debt) =>
      _update(debt.id, DebtDto.toUpdate(debt));

  @override
  Future<Debt> settleDebt(String id) => _update(id, <String, dynamic>{
    // Stamped by the client because Postgres' `now()` is not reachable through
    // PostgREST without an RPC, and a dedicated function for one timestamp is
    // more moving parts than the problem deserves. A device clock minutes out is
    // harmless here: nothing computes against this value, it only records that
    // the debt was repaid.
    DebtDto.columnSettledAt: DateTime.now().toUtc().toIso8601String(),
  });

  @override
  Future<Debt> reopenDebt(String id) =>
      _update(id, <String, dynamic>{DebtDto.columnSettledAt: null});

  @override
  Future<void> deleteDebt(String id) async {
    _requireUserId('deleteDebt');

    return _guard(() async {
      await _client.from(DebtDto.table).delete().eq(DebtDto.columnId, id);
    });
  }

  /// One update path, so every write returns the stored row the same way.
  Future<Debt> _update(String id, Map<String, dynamic> values) async {
    // Checked even though the update does not send a user_id: without a session
    // the request goes out anonymous and RLS matches nothing, which succeeds
    // while changing zero rows. Failing here says what actually happened.
    _requireUserId('updateDebt');

    return _guard(() async {
      final Map<String, dynamic> row = await _client
          .from(DebtDto.table)
          .update(values)
          .eq(DebtDto.columnId, id)
          // single(), so an update that matched nothing is an error rather than
          // a silent success. Under RLS a non-matching id and someone else's
          // debt are the same case, and both should fail loudly to the caller —
          // which is different from `fetchDebt`, where the *user* is told
          // nothing.
          .select(DebtDto.selectColumns)
          .single();

      return DebtDto.toEntity(row);
    });
  }

  String _requireUserId(String operation) {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw AuthenticationException(
        message: 'Your session ended. Sign in again to continue.',
        debugMessage: 'SupabaseDebtRepository.$operation without a session',
      );
    }

    return userId;
  }

  /// Runs [body], converting anything it throws into an `AppException`.
  ///
  /// Wrapped here rather than in each method so no method can forget. The
  /// `FormatException` case matters as much as the Supabase ones: a row the DTO
  /// cannot read — an unrecognised `direction`, most of all — is a real failure,
  /// and letting it escape raw would leak a parser error into a UI that only
  /// knows how to show an `AppException`.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ServerException(
          debugMessage: 'Unreadable debt row: $error',
          cause: error,
        ),
        stackTrace,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapSupabaseError(error), stackTrace);
    }
  }
}
