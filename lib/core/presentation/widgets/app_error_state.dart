import 'package:flutter/material.dart';

import '../../error/app_exception.dart';
import '../../theme/app_colors.dart';
import 'app_state_message.dart';

/// Shown when something failed to load.
///
/// Takes the raw [error] rather than a string, and derives the message from it.
/// That is the point: [AppException] already carries a `userMessage` written to
/// be shown, so the screen does not get to invent its own wording — and an error
/// that is *not* an [AppException] cannot leak a stack trace into the UI,
/// because it falls back to a generic line and keeps its details in the logs.
///
/// Pair with `AsyncValue.when(error: ...)`:
///
/// ```dart
/// billsAsync.when(
///   loading: () => const AppLoadingIndicator(),
///   error: (Object error, _) =>
///       AppErrorState(error: error, onRetry: () => ref.invalidate(billsProvider)),
///   data: (List<Bill> bills) => ...,
/// )
/// ```
class AppErrorState extends StatelessWidget {
  const AppErrorState({required this.error, this.onRetry, super.key});

  /// The thrown object, passed straight through from `AsyncValue.error`.
  final Object error;

  /// Retry handler. Omit only when there is genuinely nothing to retry — a
  /// dead end with no way out is worse than a button that sometimes fails again.
  final VoidCallback? onRetry;

  /// The user-facing message. Falls back to a generic line for anything that is
  /// not one of ours, since an arbitrary `toString()` is not fit to show.
  String get _message => switch (error) {
    final AppException exception => exception.userMessage,
    _ => 'Something went wrong. Please try again.',
  };

  /// A network failure is worth its own icon: it tells the user the problem is
  /// probably on their end and retrying may actually work.
  IconData get _icon => switch (error) {
    NetworkException() => Icons.wifi_off_rounded,
    NotFoundException() => Icons.search_off_rounded,
    _ => Icons.error_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return AppStateMessage(
      icon: _icon,
      iconColor: AppColors.overdueText,
      iconBackground: AppColors.overdueTint,
      title: 'That did not work',
      message: _message,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}
