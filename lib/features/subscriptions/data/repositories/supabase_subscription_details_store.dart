import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_error_mapper.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/entities/subscription_details.dart';
import '../../domain/repositories/subscription_details_store.dart';
import '../dtos/subscription_details_dto.dart';

/// [SubscriptionDetailsStore] over Supabase.
///
/// Reads never filter on `user_id`: the RLS policy already restricts every
/// statement to `user_id = auth.uid()`. **The policy secures this, not the
/// query.** The write carries it because the column is denormalised onto this
/// table — see migration 0006 — and an inserted row cannot be attributed
/// without it.
class SupabaseSubscriptionDetailsStore implements SubscriptionDetailsStore {
  const SupabaseSubscriptionDetailsStore(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, SubscriptionDetails>> fetchAll() async {
    return _guard(() async {
      final List<Map<String, dynamic>> rows = await _client
          .from(SubscriptionDetailsDto.tableName)
          .select(SubscriptionDetailsDto.selectColumns);

      return <String, SubscriptionDetails>{
        for (final Map<String, dynamic> row in rows)
          if (SubscriptionDetailsDto.toEntity(row)
              case final SubscriptionDetails details
              when details.recurringBillId.isNotEmpty)
            details.recurringBillId: details,
      };
    });
  }

  @override
  Future<SubscriptionDetails?> fetch(String recurringBillId) async {
    return _guard(() async {
      final Map<String, dynamic>? row = await _client
          .from(SubscriptionDetailsDto.tableName)
          .select(SubscriptionDetailsDto.selectColumns)
          // maybeSingle, not single: a missing row is a null, not an exception.
          .eq(SubscriptionDetailsDto.columnRecurringBillId, recurringBillId)
          .maybeSingle();

      return row == null ? null : SubscriptionDetailsDto.toEntity(row);
    });
  }

  @override
  Future<SubscriptionDetails> save(SubscriptionDetails details) async {
    final String userId = _requireUserId();

    return _guard(() async {
      final Map<String, dynamic> row = await _client
          .from(SubscriptionDetailsDto.tableName)
          .upsert(SubscriptionDetailsDto.toUpsert(details, userId: userId))
          .select(SubscriptionDetailsDto.selectColumns)
          .single();

      return SubscriptionDetailsDto.toEntity(row);
    });
  }

  String _requireUserId() {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw const AuthenticationException(
        message: 'Your session ended. Sign in again to continue.',
        debugMessage: 'SupabaseSubscriptionDetailsStore.save without a session',
      );
    }

    return userId;
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapSupabaseError(error), stackTrace);
    }
  }
}
