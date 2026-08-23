import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'app_button.dart';

/// Shows a PayPaw dialog.
///
/// Shape, surface and radius come from the theme; this function exists so no
/// screen has to assemble an `AlertDialog` and re-decide the title style and
/// action layout each time.
///
/// Returns whatever the dialog is popped with, or null if it was dismissed.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  List<Widget> actions = const <Widget>[],
  bool barrierDismissible = true,
}) {
  assert(
    message == null || content == null,
    'Pass either a message or a content widget, not both.',
  );

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext context) {
      final TextTheme textTheme = Theme.of(context).textTheme;

      return AlertDialog(
        title: Text(title, style: textTheme.titleLarge),
        content:
            content ??
            (message == null
                ? null
                : Text(message, style: textTheme.bodyMedium)),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          AppSpacing.xl,
        ),
        actions: actions.isEmpty ? null : actions,
      );
    },
  );
}

/// Asks the user to confirm before something irreversible happens.
///
/// Resolves to `true` only on an explicit confirm — dismissing the dialog, or
/// backing out of it, resolves to `false`. Never treat a dismissal as consent.
///
/// Set [isDestructive] when the action deletes something; the confirm button
/// turns red and the cancel action becomes the visually calmer choice.
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    title: title,
    message: message,
    actions: <Widget>[
      _DialogActions(
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    ],
  );

  return confirmed ?? false;
}

/// Confirm and cancel, stacked.
///
/// Stacked rather than side by side because both buttons are full width in this
/// design, and a destructive confirm deserves the room to be read properly.
class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
  });

  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    void close({required bool confirmed}) =>
        Navigator.of(context).pop(confirmed);

    return Column(
      children: <Widget>[
        if (isDestructive)
          AppDangerButton(
            label: confirmLabel,
            onPressed: () => close(confirmed: true),
          )
        else
          AppPrimaryButton(
            label: confirmLabel,
            onPressed: () => close(confirmed: true),
          ),
        const SizedBox(height: AppSpacing.sm),
        AppSecondaryButton(
          label: cancelLabel,
          onPressed: () => close(confirmed: false),
        ),
      ],
    );
  }
}
