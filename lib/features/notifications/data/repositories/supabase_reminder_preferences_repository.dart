import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_error_mapper.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/entities/bill_reminder_override.dart';
import '../../domain/entities/reminder_preferences.dart';
import '../../domain/repositories/reminder_preferences_repository.dart';
import '../dtos/bill_reminder_override_dto.dart';
import '../dtos/reminder_preferences_dto.dart';

/// [ReminderPreferencesRepository] over Supabase.
///
/// The reads never filter on `user_id`. The RLS policy already restricts every
/// statement to `user_id = auth.uid()`, so adding it would express the same
/// constraint a second time somewhere it can drift from the policy. **The policy
/// secures this.** The writes *do* carry it, because it is the conflict target
/// of an upsert and an inserted row cannot be attributed without it.
class SupabaseReminderPreferencesRepository
    implements ReminderPreferencesRepository {
  const SupabaseReminderPreferencesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ReminderPreferences> fetch() async {
    return _guard(() async {
      // `maybeSingle`, not `single`: no row is the common case, not a failure.
      // Nothing seeds this table at sign-up.
      final Map<String, dynamic>? row = await _client
          .from(ReminderPreferencesDto.tableName)
          .select(ReminderPreferencesDto.selectColumns)
          .maybeSingle();

      return row == null
          ? const ReminderPreferences()
          : ReminderPreferencesDto.toEntity(row);
    });
  }

  @override
  Future<void> save(ReminderPreferences preferences) async {
    final String userId = _requireUserId('save');

    return _guard(() async {
      await _client
          .from(ReminderPreferencesDto.tableName)
          .upsert(ReminderPreferencesDto.toUpsert(preferences, userId: userId));
    });
  }

  @override
  Future<Map<String, BillReminderOverride>> fetchOverrides() async {
    return _guard(() async {
      final List<Map<String, dynamic>> rows = await _client
          .from(BillReminderOverrideDto.tableName)
          .select(BillReminderOverrideDto.selectColumns);

      return <String, BillReminderOverride>{
        for (final Map<String, dynamic> row in rows)
          if (BillReminderOverrideDto.toEntity(row)
              case final BillReminderOverride override
              when override.billId.isNotEmpty)
            override.billId: override,
      };
    });
  }

  @override
  Future<void> saveOverride(BillReminderOverride override) async {
    final String userId = _requireUserId('saveOverride');

    return _guard(() async {
      // Nothing left to override means no row. See the contract: the table's
      // own check constraint refuses one, and a row that means nothing is a row
      // every later reader has to reason about.
      if (override.isEmpty) {
        await _client
            .from(BillReminderOverrideDto.tableName)
            .delete()
            .eq(BillReminderOverrideDto.columnBillId, override.billId);

        return;
      }

      await _client
          .from(BillReminderOverrideDto.tableName)
          .upsert(BillReminderOverrideDto.toUpsert(override, userId: userId));
    });
  }

  String _requireUserId(String operation) {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw AuthenticationException(
        message: 'Your session ended. Sign in again to continue.',
        debugMessage:
            'SupabaseReminderPreferencesRepository.$operation without a session',
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
