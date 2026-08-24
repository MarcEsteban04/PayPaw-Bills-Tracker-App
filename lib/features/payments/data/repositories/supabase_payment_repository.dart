import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_error_mapper.dart';
import '../../../../core/error/app_exception.dart';
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
