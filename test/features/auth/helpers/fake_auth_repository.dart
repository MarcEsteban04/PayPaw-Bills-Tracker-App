import 'package:paypaw/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:paypaw/features/auth/domain/repositories/auth_repository.dart';

/// A hand-written stand-in for [AuthRepository].
///
/// No mocking package: the interface has one method, and a fake that records
/// what it was called with is both shorter to read and stricter than a mock set
/// up with matchers. It also means these tests describe the *contract* rather
/// than the SDK.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.outcome, this.error, this.delay = Duration.zero})
    : assert(
        outcome == null || error == null,
        'Give the fake an outcome or an error, not both.',
      );

  /// What `signUp` should return. Defaults to needing confirmation, which is
  /// PayPaw's normal path.
  final SignUpOutcome? outcome;

  /// What `signUp` should throw instead of returning.
  final Object? error;

  /// How long `signUp` takes, for testing the in-flight state.
  final Duration delay;

  /// How many times `signUp` was called — the double-submit guard depends on it.
  int signUpCalls = 0;

  String? lastEmail;
  String? lastPassword;

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    lastEmail = email;
    lastPassword = password;

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (error case final Object failure) {
      throw failure;
    }

    return outcome ?? const SignUpNeedsConfirmation(email: 'fake@example.com');
  }
}
