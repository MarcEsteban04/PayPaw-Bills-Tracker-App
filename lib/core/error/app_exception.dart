/// The single error hierarchy for PayPaw.
///
/// The data layer converts every low-level error — a `SocketException`, a
/// Supabase `PostgrestException`, a platform channel failure — into one of
/// these before it leaves the repository. Above that boundary, nothing needs to
/// know which backend produced the error.
///
/// Each exception carries two messages on purpose:
///
/// * [userMessage] is safe to render in the UI. It must never contain a stack
///   trace, an identifier, or a provider name.
/// * [debugMessage] is for logs only and may contain anything useful.
///
/// There is deliberately no separate `Failure` type mirroring this hierarchy.
/// Riverpod's `AsyncValue` already carries the error into the presentation
/// layer, so a second parallel hierarchy would be duplication with no payoff.
sealed class AppException implements Exception {
  const AppException({
    required this.userMessage,
    this.debugMessage,
    this.cause,
  });

  /// Message safe to display to the user.
  final String userMessage;

  /// Detail for logs and crash reports. Never shown in the UI.
  final String? debugMessage;

  /// The original error this was converted from, when there was one.
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType(userMessage: $userMessage, debugMessage: $debugMessage, '
      'cause: $cause)';
}

/// The device could not reach the network at all.
final class NetworkException extends AppException {
  const NetworkException({super.debugMessage, super.cause})
    : super(
        userMessage:
            'No internet connection. Check your network and try again.',
      );
}

/// The backend was reachable but returned an error.
final class ServerException extends AppException {
  const ServerException({super.debugMessage, super.cause})
    : super(userMessage: 'Something went wrong on our end. Please try again.');
}

/// Sign-in, sign-up, or session refresh failed.
final class AuthenticationException extends AppException {
  const AuthenticationException({
    required String message,
    super.debugMessage,
    super.cause,
  }) : super(userMessage: message);
}

/// The requested record does not exist, or is not visible to this user.
final class NotFoundException extends AppException {
  const NotFoundException({
    String message = 'We could not find what you were looking for.',
    super.debugMessage,
    super.cause,
  }) : super(userMessage: message);
}

/// Input failed a business rule — an empty bill name, a negative amount.
final class ValidationException extends AppException {
  const ValidationException({
    required String message,
    super.debugMessage,
    super.cause,
  }) : super(userMessage: message);
}

/// Reading or writing local storage failed.
final class CacheException extends AppException {
  const CacheException({super.debugMessage, super.cause})
    : super(userMessage: 'Could not read saved data on this device.');
}

/// Fallback for anything not yet classified. Reaching this in production is a
/// signal that the mapper needs another case, not that the UI needs a fix.
final class UnexpectedException extends AppException {
  const UnexpectedException({super.debugMessage, super.cause})
    : super(userMessage: 'Something unexpected happened. Please try again.');
}
