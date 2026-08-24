import 'dart:async';

import 'package:paypaw/features/auth/domain/entities/authenticated_user.dart';
import 'package:paypaw/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:paypaw/features/auth/domain/repositories/auth_repository.dart';

/// A hand-written stand-in for [AuthRepository].
///
/// No mocking package: the interface is small, and a fake that records what it
/// was called with is both shorter to read and stricter than a mock configured
/// with matchers. It also means these tests describe the *contract* rather than
/// the SDK.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.outcome,
    this.signedInUser = const AuthenticatedUser(
      id: 'user-1',
      email: 'marc@example.com',
      hasConfirmedEmail: true,
    ),
    this.error,
    this.delay = Duration.zero,
    AuthenticatedUser? initialUser,
  }) : _currentUser = initialUser;

  /// What `signUp` returns. Defaults to needing confirmation, PayPaw's normal
  /// path.
  final SignUpOutcome? outcome;

  /// What `signIn` returns.
  final AuthenticatedUser signedInUser;

  /// Thrown instead of returning, by whichever method is called.
  final Object? error;

  /// How long a call takes, for testing the in-flight state.
  final Duration delay;

  final StreamController<AuthenticatedUser?> _sessions =
      StreamController<AuthenticatedUser?>.broadcast();

  AuthenticatedUser? _currentUser;

  int signUpCalls = 0;
  int signInCalls = 0;
  String? lastEmail;
  String? lastPassword;

  @override
  AuthenticatedUser? get currentUser => _currentUser;

  @override
  Stream<AuthenticatedUser?> authStateChanges() => _sessions.stream;

  /// Pushes a session change, standing in for a token refresh, a sign-out from
  /// another device, or an expiry.
  void emitSession(AuthenticatedUser? user) {
    _currentUser = user;
    _sessions.add(user);
  }

  /// Stands in for a password reset link being opened on the device.
  void emitPasswordRecovery() => _recoveries.add(null);

  /// Stands in for a session ending on its own — a refresh token rejected, or a
  /// stored session that could not be restored.
  void emitSessionExpiry() {
    _currentUser = null;
    _expiries.add(null);
    _sessions.add(null);
  }

  int signOutCalls = 0;

  final StreamController<void> _expiries = StreamController<void>.broadcast();

  @override
  Stream<void> sessionExpirations() => _expiries.stream;

  @override
  Future<void> signOut() async {
    signOutCalls++;

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (error case final Object failure) {
      throw failure;
    }

    _currentUser = null;
    _sessions.add(null);
  }

  /// Call from a test teardown.
  Future<void> dispose() async {
    await _sessions.close();
    await _recoveries.close();
    await _expiries.close();
  }

  int sendPasswordResetCalls = 0;
  int updatePasswordCalls = 0;
  String? lastResetEmail;
  String? lastNewPassword;

  final StreamController<void> _recoveries = StreamController<void>.broadcast();

  @override
  Stream<void> passwordRecoveryRequests() => _recoveries.stream;

  @override
  Future<void> sendPasswordReset({required String email}) async {
    sendPasswordResetCalls++;
    lastResetEmail = email;
    await _record(email, '');
  }

  @override
  Future<AuthenticatedUser> updatePassword({
    required String newPassword,
  }) async {
    updatePasswordCalls++;
    lastNewPassword = newPassword;
    await _record(lastEmail ?? '', newPassword);

    _currentUser = signedInUser;
    _sessions.add(signedInUser);

    return signedInUser;
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    await _record(email, password);

    return outcome ?? const SignUpNeedsConfirmation(email: 'fake@example.com');
  }

  @override
  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    await _record(email, password);

    _currentUser = signedInUser;
    _sessions.add(signedInUser);

    return signedInUser;
  }

  Future<void> _record(String email, String password) async {
    lastEmail = email;
    lastPassword = password;

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (error case final Object failure) {
      throw failure;
    }
  }
}
