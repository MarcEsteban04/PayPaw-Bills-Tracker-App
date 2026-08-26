import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';

/// One shortcut.
@immutable
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

/// The shortcuts under the headline.
///
/// ## Two kinds of thing, drawn as two kinds of thing
///
/// This was one scrolling strip of identical circles, and that was the problem.
/// "Add bill" **records something**; "Calendar" **goes somewhere that is already
/// a tab at the bottom of this very screen**. Drawing them the same size, in the
/// same colour, at the same weight said they were equally important, and the
/// most-used action in a bills app was indistinguishable from a duplicate of the
/// navigation bar.
///
/// So [actions] — the ones that change data — are wide buttons on the first row,
/// the first of them filled in the accent because it is the thing people open
/// this app to do. [destinations] are quieter tiles below, with muted icons,
/// because going somewhere is not an achievement.
///
/// ## Nothing scrolls, and nothing hides
///
/// The strip scrolled sideways, which meant a fifth shortcut existed only for
/// somebody who happened to swipe a row that gave no sign it could be swiped. A
/// shortcut you have to discover by accident is not a shortcut.
///
/// Both rows divide the width they are given, so five fit on a 320dp phone
/// without a scroll, without an overflow, and without shrinking a word to make
/// it squeeze — which is what the old 72dp grid forced on "Subscriptions".
///
/// ## Only things that work are here
///
/// Sprint 37's list also names "Add debt"; debts are Phase 11, so it has nowhere
/// to go. A row where one entry does nothing teaches the user that the row is
/// decoration, and they stop reading it. The rule runs per-user as well as
/// per-sprint: "Mark paid" is absent for somebody with nothing outstanding,
/// because an action that opens onto an empty list is the same broken promise as
/// one that is not built.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({
    required this.actions,
    required this.destinations,
    super.key,
  });

  /// The shortcuts that change something. The first is the primary one.
  final List<QuickAction> actions;

  /// The shortcuts that only navigate.
  final List<QuickAction> destinations;

  /// Height of one action button.
  ///
  /// Public so the loading placeholder can lay itself out on the same geometry.
  /// A skeleton built to different measurements makes the whole row jump the
  /// moment the data lands — which is the jump a skeleton exists to prevent,
  /// reintroduced by the thing meant to prevent it.
  static const double actionHeight = 52;

  /// Height of one destination tile.
  static const double destinationHeight = 74;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (actions.isNotEmpty)
          _Row(
            children: <Widget>[
              for (final (int index, QuickAction action) in actions.indexed)
                _ActionButton(action: action, isPrimary: index == 0),
            ],
          ),
        if (actions.isNotEmpty && destinations.isNotEmpty)
          const SizedBox(height: AppSpacing.cardGap),
        if (destinations.isNotEmpty)
          _Row(
            children: <Widget>[
              for (final QuickAction destination in destinations)
                _Destination(action: destination),
            ],
          ),
      ],
    );
  }
}

/// Equal columns with a gap between them.
///
/// `Expanded` rather than a fixed item width: the old row used 72dp per item and
/// overflowed a 320dp phone at five, so it scrolled — and a scrolling row hides
/// whatever does not fit. Dividing the available width instead means the count
/// can change without anything disappearing.
class _Row extends StatelessWidget {
  const _Row({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // No `CrossAxisAlignment.stretch`. This row sits in a column of unbounded
    // height, and stretching a row's children across that hands them an infinite
    // height constraint. Each tile sets its own height, so the row takes theirs.
    return Row(
      children: <Widget>[
        for (final (int index, Widget child) in children.indexed) ...<Widget>[
          if (index > 0) const SizedBox(width: AppSpacing.cardGap),
          Expanded(child: child),
        ],
      ],
    );
  }
}

/// Something that changes data: recording a bill, settling one.
///
/// Horizontal — icon beside the label rather than above it — because these are
/// buttons and buttons read left to right. It also gives the label the full
/// width of the tile, which is what a long word needs.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.isPrimary});

  final QuickAction action;

  /// Whether this is *the* action of the screen.
  ///
  /// Exactly one is, and it is filled. A row where everything is emphasised is a
  /// row where nothing is.
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Color background = isPrimary ? colors.primary : colors.surface;
    final Color foreground = isPrimary
        ? colors.textOnPrimary
        : colors.textPrimary;

    return Semantics(
      button: true,
      label: action.label,
      child: Material(
        color: background,
        borderRadius: AppRadii.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action.onPressed,
          child: Container(
            height: DashboardQuickActions.actionHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  action.icon,
                  size: 20,
                  color: isPrimary ? foreground : colors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: _Label(
                    action.label,
                    style: textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Somewhere to go.
///
/// Vertical — icon above the label — so three fit across a narrow phone, and
/// **muted**, not accented. Two of these three are also tabs in the navigation
/// bar; painting them in the same green as the action that records a bill said
/// they mattered as much, and they do not.
class _Destination extends StatelessWidget {
  const _Destination({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: action.label,
      child: Material(
        color: colors.surface,
        borderRadius: AppRadii.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action.onPressed,
          child: Container(
            height: DashboardQuickActions.destinationHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(action.icon, size: 22, color: colors.textSecondary),
                const SizedBox(height: AppSpacing.sm),
                _Label(
                  action.label,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One shortcut's caption, on one line, whatever it says.
///
/// Every label here fits at full size on a 320dp phone, including
/// "Subscriptions" — which the old 72dp grid could not hold, and rendered as
/// "Subscription" above a lone "s".
///
/// The shrink-to-fit stays as insurance for a large system text scale, where the
/// choice is between a slightly smaller word and a clipped one. It never fires
/// at the default scale.
class _Label extends StatelessWidget {
  const _Label(this.text, {required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
        style: style,
      ),
    );
  }
}
