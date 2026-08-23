import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/data/supabase_error_mapper.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/entities/sign_up_outcome.dart';
import '../../domain/repositories/auth_repository.dart';

/// Supabase-backed [AuthRepository].
///
/// There is no separate data source class here, and that is deliberate. A data
/// source earns its place when there is JSON to map or more than one source to
/// coordinate; `signUp` is a single typed SDK call, so a data source would be a
/// pass-through whose only job is to be a layer. This class is the Supabase
/// boundary: it is the only place in the feature that imports
/// `supabase_flutter`, and nothing Supabase-shaped leaves it.
class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        // Without this the confirmation link opens a browser page instead of
        // coming back to the app. The URL must also be registered in the
        // Supabase dashboard — see docs/supabase_setup.md.
        emailRedirectTo: AppConfig.authRedirectUrl,
      );

      return _outcomeOf(response, email.trim());
    } on AuthException catch (error) {
      throw _mapAuthError(error);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Reads the two successful endings apart.
  ///
  /// A session means confirmation is disabled and the user is already signed in.
  /// No session but a user means the confirmation email is on its way, which is
  /// the normal path for PayPaw.
  SignUpOutcome _outcomeOf(AuthResponse response, String email) {
    final User? user = response.user;

    if (user == null) {
      // Supabase returns a null user for an already-registered address when
      // "confirm email" is on, rather than an error — it refuses to confirm or
      // deny that the address exists. Reporting it as already registered would
      // hand an attacker exactly the answer Supabase is withholding, so this is
      // reported the same way a genuine new signup is.
      return SignUpNeedsConfirmation(email: email);
    }

    if (response.session != null) {
      return SignUpSignedIn(user: _toEntity(user, email));
    }

    return SignUpNeedsConfirmation(email: email);
  }

  AuthenticatedUser _toEntity(User user, String fallbackEmail) =>
      AuthenticatedUser(
        id: user.id,
        email: user.email ?? fallbackEmail,
        hasConfirmedEmail: user.emailConfirmedAt != null,
      );

  /// Turns an auth failure into something worth showing a user.
  ///
  /// Supabase's own messages are usually good, but a few cases deserve better
  /// wording than the API gives, and one — a rate limit — is easy to mistake for
  /// a broken app.
  AppException _mapAuthError(AuthException error) {
    final String debug = '${error.code}: ${error.message}';

    return switch (error.code) {
      'user_already_exists' || 'email_exists' => ValidationException(
        message:
            'That email is already registered. Try signing in instead, or '
            'reset your password.',
        debugMessage: debug,
        cause: error,
      ),
      'weak_password' => ValidationException(
        message: 'That password is too easy to guess. Try a longer one.',
        debugMessage: debug,
        cause: error,
      ),
      'over_email_send_rate_limit' ||
      'over_request_rate_limit' => ValidationException(
        message: 'Too many attempts. Wait a minute and try again.',
        debugMessage: debug,
        cause: error,
      ),
      'validation_failed' => ValidationException(
        message: 'Check your email and password and try again.',
        debugMessage: debug,
        cause: error,
      ),
      // Anything else, including network failures dressed up as auth errors,
      // goes through the shared mapper so the classification stays in one place.
      _ => mapSupabaseError(error),
    };
  }
}

/// The app's [AuthRepository].
///
/// Depends on `supabaseClientProvider`, so reading it before Supabase is
/// configured throws with a message that says so rather than failing later.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (Ref ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
    );
