import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_error_mapper.dart';
import '../../domain/entities/reminder_preferences.dart';
import '../../domain/repositories/reminder_preferences_repository.dart';
import '../dtos/reminder_preferences_dto.dart';

/// [ReminderPreferencesRepository] over Supabase.
///
/// The query never filters on `user_id`. The RLS policy already restricts every
/// statement to `user_id = auth.uid()`, so adding it would express the same
/// constraint a second time somewhere it can drift from the policy. **The policy
/// secures this.**
class SupabaseReminderPreferencesRepository
    implements ReminderPreferencesRepository {
  const SupabaseReminderPreferencesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ReminderPreferences> fetch() async {
    try {
      // `maybeSingle`, not `single`: no row is the common case, not a failure.
      // Nothing seeds this table at sign-up.
      final Map<String, dynamic>? row = await _client
          .from(ReminderPreferencesDto.tableName)
          .select(ReminderPreferencesDto.selectColumns)
          .maybeSingle();

      return row == null
          ? const ReminderPreferences()
          : ReminderPreferencesDto.toEntity(row);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapSupabaseError(error), stackTrace);
    }
  }
}
