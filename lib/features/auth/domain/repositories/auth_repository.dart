import '../entities/authenticated_user.dart';
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

  /// Signs an existing user in.
  ///
  /// Throws `AuthenticationException` for wrong credentials and for an
  /// unconfirmed address — two failures worth telling apart, since only one of
  /// them is the user's mistake.
  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  });

  /// Who is signed in right now, or null.
  ///
  /// Synchronous, because the SDK restores a stored session before the first
  /// frame. That is what lets a route guard decide immediately rather than
  /// flashing a sign-in screen at an already-authenticated user.
  AuthenticatedUser? get currentUser;

  /// Emits whenever the session changes: signing in, signing out, a token
  /// refresh, or a session expiring on its own.
  ///
  /// The stream is the source of truth for "who is signed in", not a value read
  /// once at startup — a session can end without the user asking, and the app
  /// has to notice.
  Stream<AuthenticatedUser?> authStateChanges();
}
