import 'package:flutter/material.dart';

import 'app_state_message.dart';

/// Shown where a list has nothing in it.
///
/// An empty list is not a failure, so this reads as an invitation rather than a
/// problem: neutral colours, and an action that fills the gap where one exists.
///
/// Write [title] and [message] for the *specific* emptiness. "No bills yet" with
/// "Add your first bill and PayPaw will remind you before it is due" tells the
/// user what to do; a generic "No data" does not.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  /// Label for the action that resolves the emptiness — 'Add a bill'.
  final String? actionLabel;

  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppStateMessage(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
