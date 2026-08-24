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

  /// Sends a password reset email.
  ///
  /// Completes successfully **whether or not the address has an account**.
  /// Supabase deliberately does not say, and neither should the app: an endpoint
  /// that reports "no such user" is a way to enumerate who is registered here.
  ///
  /// Throws `ValidationException` when the backend rate-limits the request, which
  /// is easy to mistake for the app being broken.
  Future<void> sendPasswordReset({required String email});

  /// Sets a new password for the user in the current session.
  ///
  /// Requires a session — either a normal one, or the temporary recovery session
  /// created when a reset link is opened. Throws `AuthenticationException` when
  /// there is none, which is what an expired or reused link looks like.
  Future<AuthenticatedUser> updatePassword({required String newPassword});

  /// Ends the session on this device.
  ///
  /// Local only: it does not revoke sessions on the user's other devices. That is
  /// the expected behaviour of a sign-out button, and the alternative would
  /// silently log them out of their tablet.
  Future<void> signOut();

  /// Emits when the session ended **without the user asking** — a refresh token
  /// expired or was rejected, or a stored session could not be restored.
  ///
  /// Separate from [authStateChanges] because the app needs to tell the two
  /// apart: an explicit sign-out needs no explanation, and being silently
  /// returned to a sign-in screen does.
  Stream<void> sessionExpirations();

  /// Emits when a password reset link has been opened and a recovery session
  /// exists, so the app can ask for the new password.
  ///
  /// A stream because the link can arrive at any moment — the app may be on any
  /// screen, or may have been launched by the link itself.
  Stream<void> passwordRecoveryRequests();

  /// Emits whenever the session changes: signing in, signing out, a token
  /// refresh, or a session expiring on its own.
  ///
  /// The stream is the source of truth for "who is signed in", not a value read
  /// once at startup — a session can end without the user asking, and the app
  /// has to notice.
  Stream<AuthenticatedUser?> authStateChanges();
}
