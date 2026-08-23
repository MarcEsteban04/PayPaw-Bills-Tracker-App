import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import 'app_button.dart';

/// The shared layout behind `AppEmptyState` and `AppErrorState`: a tinted icon,
/// a short heading, an explanation, and at most one action.
///
/// One layout for both, because an empty list and a failed load are the same
/// shape of message to the user — *nothing to show, and here is what you can do
/// about it.* Building them separately would let them drift apart visually for
/// no reason.
///
/// Use [AppEmptyState] or [AppErrorState] rather than this directly; reach for
/// it only for a state neither of those covers.
class AppStateMessage extends StatelessWidget {
  const AppStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor = AppColors.primaryText,
    this.iconBackground = AppColors.primarySoft,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Icon representing the situation.
  final IconData icon;

  /// One short line. A statement, not an apology.
  final String title;

  /// What it means, and what to do next.
  final String message;

  final Color iconColor;
  final Color iconBackground;

  /// Action label. Ignored unless [onAction] is also given.
  final String? actionLabel;

  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: AppRadii.panel,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Icon(icon, size: 32, color: iconColor),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            if (actionLabel case final String label
                when onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              // Not full width: a message centred in empty space with a
              // full-width button under it reads as a form, not a suggestion.
              AppPrimaryButton(
                label: label,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
