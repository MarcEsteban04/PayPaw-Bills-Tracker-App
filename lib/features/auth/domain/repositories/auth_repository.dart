import '../entities/sign_up_outcome.dart';

/// What PayPaw needs from an authentication backend.
///
/// Pure Dart: no Supabase types cross this boundary. Implementations translate
/// every backend failure into an `AppException` before it reaches a caller, so
/// nothing above this layer knows which service is behind it.
abstract interface class AuthRepository {
  /// Creates an account.
  ///
  /// Returns which of the two successful endings happened — see [SignUpOutcome].
  ///
  /// Throws `ValidationException` when the address is already registered or the
  /// backend rejects the password, `NetworkException` when it could not be
  /// reached, and `AuthenticationException` for anything else the auth service
  /// refused.
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  });
}
