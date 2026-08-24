import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';

/// Swipe a bill right to edit it, left to delete it.
///
/// ## Why `Dismissible` and not a gesture of my own
///
/// It already handles the fling threshold, the rubber-banding, the resize
/// animation on removal and the accessibility of all three. Writing that by hand
/// would be a worse version of it.
///
/// The subtlety is that only one of the two directions actually dismisses. Edit
/// leaves the bill where it is, so `confirmDismiss` runs the callback and then
/// answers **false** — the row springs back, the editor opens over it. Delete
/// answers whatever the confirmation dialog said, and only a true takes the row
/// out of the list.
///
/// That asymmetry is the whole reason this is a widget rather than four lines
/// inline: getting it wrong means a row that vanishes when you meant to edit it,
/// and the list disagreeing with the database until the next refresh.
class BillSwipeActions extends StatelessWidget {
  const BillSwipeActions({
    required this.billKey,
    required this.onEdit,
    required this.confirmDelete,
    required this.child,
    super.key,
  });

  /// Identifies the row across rebuilds. The bill's id, not its index — an index
  /// key makes `Dismissible` animate the wrong row out when the list reorders.
  final String billKey;

  /// Opens the editor. Called before the row springs back.
  final VoidCallback onEdit;

  /// Asks the user, then deletes. True if the row should leave the list.
  final Future<bool> Function() confirmDelete;

  final Widget child;

  /// How far the row must travel before the gesture counts.
  ///
  /// Higher than Material's 0.4 default in the delete direction: a destructive
  /// action reached by accident is worse than one that needs a firmer push. Edit
  /// is harmless, so it keeps a lighter threshold.
  static const double _editThreshold = 0.3;
  static const double _deleteThreshold = 0.55;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey<String>('bill-swipe-$billKey'),
      dismissThresholds: const <DismissDirection, double>{
        DismissDirection.startToEnd: _editThreshold,
        DismissDirection.endToStart: _deleteThreshold,
      },
      background: const _SwipeBackground(
        alignment: Alignment.centerLeft,
        icon: Icons.edit_rounded,
        label: 'Edit',
        isDestructive: false,
      ),
      secondaryBackground: const _SwipeBackground(
        alignment: Alignment.centerRight,
        icon: Icons.delete_outline_rounded,
        label: 'Delete',
        isDestructive: true,
      ),
      confirmDismiss: (DismissDirection direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();

          // False: the bill is still here. Returning true would animate the row
          // out from under the editor that just opened over it.
          return false;
        }

        return confirmDelete();
      },
      child: child,
    );
  }
}

/// What shows behind the row as it slides.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.isDestructive,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    // Tinted rather than solid, and matching the row's own corner radius, so the
    // gesture looks like it belongs to the card rather than revealing a coloured
    // slab behind it.
    final Color background = isDestructive
        ? colors.overdueTint
        : colors.primarySoft;
    final Color foreground = isDestructive
        ? colors.overdueText
        : colors.primaryText;

    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: AppRadii.card),
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
