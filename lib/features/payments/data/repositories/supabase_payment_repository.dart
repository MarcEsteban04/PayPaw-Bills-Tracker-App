import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_error_mapper.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/entities/new_payment.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_repository.dart';
import '../dtos/payment_dto.dart';

/// [PaymentRepository] over Supabase.
///
/// No data source class, for the same reason `SupabaseBillRepository` has none:
/// every method is one PostgREST call plus a mapping. This stays the only file in
/// the feature that imports `supabase_flutter`.
///
/// The query never filters on `user_id`. The RLS policy already restricts every
/// statement to `user_id = auth.uid()`, so adding it would express the same
/// constraint a second time somewhere it can drift from the policy — and would
/// read as though the query were doing the securing. **The policy secures this.**
class SupabasePaymentRepository implements PaymentRepository {
  const SupabasePaymentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Payment>> fetchPaymentsForBill(String billId) async {
    return _guard(() async {
      final List<Map<String, dynamic>> rows = await _client
          .from(PaymentDto.tableName)
          .select(PaymentDto.selectColumns)
          .eq(PaymentDto.columnBillId, billId)
          // Most recent first. `ascending: false` is spelled out even though it
          // matches postgrest-dart's default, because that default is the
          // opposite of what reading the method name suggests — it sorted the
          // bills list backwards once already.
          .order(PaymentDto.columnPaidAt, ascending: false);

      return rows.map(PaymentDto.toEntity).toList();
    });
  }

  @override
  Future<List<Payment>> fetchPaymentsForDebt(String debtId) async {
    return _guard(() async {
      final List<Map<String, dynamic>> rows = await _client
          .from(PaymentDto.tableName)
          .select(PaymentDto.selectColumns)
          .eq(PaymentDto.columnDebtId, debtId)
          // Most recent first, and spelled out for the reason above.
          .order(PaymentDto.columnPaidAt, ascending: false);

      return rows.map(PaymentDto.toEntity).toList();
    });
  }

  @override
  Future<Payment> recordPayment(NewPayment draft) async {
    final String userId = _requireUserId('recordPayment');

    return _guard(() async {
      // `select().single()` so the insert hands back the stored row: the caller
      // needs the id and the timestamps the database assigned, and re-fetching to
      // find them is a second round trip for what the first one can return.
      final Map<String, dynamic> row = await _client
          .from(PaymentDto.tableName)
          .insert(PaymentDto.toInsert(draft, userId: userId))
          .select(PaymentDto.selectColumns)
          .single();

      return PaymentDto.toEntity(row);
    });
  }

  String _requireUserId(String operation) {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw AuthenticationException(
        message: 'Your session ended. Sign in again to continue.',
        debugMessage: 'SupabasePaymentRepository.$operation without a session',
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
          debugMessage: 'Unreadable payment row: $error',
          cause: error,
        ),
        stackTrace,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapSupabaseError(error), stackTrace);
    }
  }
}
