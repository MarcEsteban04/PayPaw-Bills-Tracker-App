import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../error/app_exception.dart';

/// Converts errors thrown by the Supabase SDK into PayPaw's [AppException]
/// hierarchy.
///
/// This is the only place in the app that is allowed to know Supabase's error
/// types. Every repository implementation funnels its `catch` blocks through
/// [mapSupabaseError], so the layers above stay backend-agnostic and a future
/// backend swap touches this file instead of every repository.
///
/// Note: this file imports `dart:io`, so it is native-only (Android, iOS,
/// desktop). PayPaw ships to Android, so that is fine; if a web build is ever
/// needed, the [SocketException] branch has to move behind a conditional
/// import.
AppException mapSupabaseError(Object error) {
  final String debug = '$error';

  return switch (error) {
    // Already mapped somewhere deeper in the call chain — pass it through
    // rather than wrapping it twice.
    final AppException e => e,

    // Auth failed because the request never reached the server.
    AuthRetryableFetchException() => NetworkException(
      debugMessage: debug,
      cause: error,
    ),

    // The user's session is gone; treat as an auth problem so the UI can send
    // them back to sign-in.
    AuthSessionMissingException() => AuthenticationException(
      message: 'Your session expired. Please sign in again.',
      debugMessage: debug,
      cause: error,
    ),

    // Supabase already returns a human-readable message for these ("Invalid
    // login credentials", "User already registered"), so it is surfaced as-is.
    final AuthException e => AuthenticationException(
      message: e.message,
      debugMessage: debug,
      cause: error,
    ),

    // PGRST116 is "no rows returned" from a query that required exactly one.
    PostgrestException(code: 'PGRST116') => NotFoundException(
      debugMessage: debug,
      cause: error,
    ),

    // 23505 is Postgres' unique-constraint violation.
    PostgrestException(code: '23505') => const ValidationException(
      message: 'That already exists.',
    ),

    PostgrestException() => ServerException(debugMessage: debug, cause: error),

    StorageException() => ServerException(debugMessage: debug, cause: error),

    // No route to the host, DNS failure, connection refused.
    SocketException() ||
    HttpException() => NetworkException(debugMessage: debug, cause: error),

    _ => UnexpectedException(debugMessage: debug, cause: error),
  };
}
