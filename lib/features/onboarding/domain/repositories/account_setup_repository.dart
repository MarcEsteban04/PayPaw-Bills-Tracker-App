import '../entities/account_setup.dart';

/// Writes the answers onboarding collects.
///
/// One method, because the two writes belong together: an account with a
/// currency but no reminder preferences is a half-configured account, and the
/// caller should not have to know it takes two statements.
abstract interface class AccountSetupRepository {
  /// Persists [setup] for the signed-in user.
  ///
  /// Throws an `AppException` on failure. Requires a session — every target row
  /// is protected by a policy comparing against `auth.uid()`.
  Future<void> save(AccountSetup setup);
}
