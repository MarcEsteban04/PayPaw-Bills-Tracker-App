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
    // Centred when there is room, scrollable when there is not.
    //
    // An icon, two blocks of text and a button stop fitting a short container
    // once the system font is turned up — a phone in landscape, a split-screen
    // pane, a card with a fixed height. Scrolling is the honest answer:
    // shrinking the text would undo the setting the user chose.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // Zero when the height is unbounded — inside a ListView there is
              // nothing to centre against, and asking for infinity would throw.
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Center(child: _Body(message: this)),
          ),
        );
      },
    );
  }
}

/// The message itself. Split out so the scroll-and-centre wrapper above stays
/// readable.
class _Body extends StatelessWidget {
  const _Body({required this.message});

  final AppStateMessage message;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Decorative: the title and message carry the meaning, so a screen
          // reader announcing the icon as well would only add noise.
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: message.iconBackground,
                borderRadius: AppRadii.panel,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Icon(message.icon, size: 32, color: message.iconColor),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            message.title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message.message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
          if (message.actionLabel case final String label
              when message.onAction != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            // Not full width: a message centred in empty space with a
            // full-width button under it reads as a form, not a suggestion.
            AppPrimaryButton(
              label: label,
              onPressed: message.onAction,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}
