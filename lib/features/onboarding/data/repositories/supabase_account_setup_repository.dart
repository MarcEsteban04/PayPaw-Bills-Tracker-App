import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_error_mapper.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/entities/account_setup.dart';
import '../../domain/repositories/account_setup_repository.dart';
import '../dtos/account_setup_dto.dart';

/// Writes onboarding's answers to Supabase.
///
/// No data source class: this is two typed SDK calls with nothing to coordinate
/// beyond their order, so a data source would be a layer whose only job is to be
/// a layer. See the table in docs/architecture.md.
class SupabaseAccountSetupRepository implements AccountSetupRepository {
  const SupabaseAccountSetupRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> save(AccountSetup setup) async {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      // Reachable if the session ends mid-form. Failing here beats sending an
      // anonymous request that RLS rejects with a message about policies.
      throw const AuthenticationException(
        message: 'Your session ended. Sign in again to finish setting up.',
        debugMessage: 'AccountSetupRepository.save called without a session',
      );
    }

    try {
      // Sequential, not concurrent, and the profile goes first. If the second
      // write fails the user has a correct currency and default reminders, which
      // is a coherent account; the other order leaves reminders configured
      // against a currency and zone that were never saved.
      //
      // Neither call is a transaction — PostgREST has no client-side
      // transactions — so onboarding is safe to re-run rather than assumed
      // atomic. That is also why the reminder write is an upsert.
      await _client
          .from(AccountSetupDto.profilesTable)
          .update(AccountSetupDto.toProfileUpdate(setup))
          .eq(AccountSetupDto.columnProfileId, userId);

      await _client
          .from(AccountSetupDto.reminderPreferencesTable)
          .upsert(
            AccountSetupDto.toReminderUpsert(setup, userId: userId),
            onConflict: AccountSetupDto.columnUserId,
          );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(mapSupabaseError(error), stackTrace);
    }
  }
}
