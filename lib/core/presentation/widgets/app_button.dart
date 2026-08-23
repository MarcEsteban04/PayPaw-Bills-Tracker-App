import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

/// PayPaw's primary action.
///
/// Most of the styling already comes from the theme, so this widget only adds
/// what a themed `FilledButton` cannot:
///
/// * the warm orange glow beneath the button, as in the reference design;
/// * a busy state that shows a spinner and blocks repeat taps.
///
/// For a plain action with neither, use `FilledButton` directly — wrapping it for
/// nothing would just be a second way to spell the same thing.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
    this.expand = true,
    super.key,
  });

  /// Button text. Keep it a verb — 'Mark as Paid', not 'OK'.
  final String label;

  /// Tapped callback. `null` disables the button, which also drops the glow —
  /// a disabled control should not look like it is inviting a tap.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// While true the button shows a spinner and ignores taps, so a slow save
  /// cannot be submitted twice.
  final bool isBusy;

  /// Whether to fill the available width. Primary actions in this design are
  /// full width, so it defaults to true.
  final bool expand;

  bool get _isEnabled => onPressed != null && !isBusy;

  @override
  Widget build(BuildContext context) {
    final Widget button = FilledButton(
      onPressed: _isEnabled ? onPressed : null,
      child: _AppButtonContent(
        label: label,
        icon: icon,
        isBusy: isBusy,
        spinnerColor: context.colors.textOnPrimary,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadii.round,
        boxShadow: _isEnabled ? context.colors.primaryGlow : null,
      ),
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// The secondary action: same geometry as [AppPrimaryButton], outlined instead
/// of filled, so the two can sit side by side without either shifting.
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isBusy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget button = OutlinedButton(
      onPressed: onPressed != null && !isBusy ? onPressed : null,
      child: _AppButtonContent(
        label: label,
        icon: icon,
        isBusy: isBusy,
        spinnerColor: context.colors.textPrimary,
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A destructive action: delete a bill, remove a debt, sign out.
///
/// Red rather than orange, and never the default focus of a screen. It exists so
/// that "this cannot be undone" is visible before the tap, not only in the
/// confirmation dialog that follows.
class AppDangerButton extends StatelessWidget {
  const AppDangerButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isBusy = false,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isBusy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget button = FilledButton(
      onPressed: onPressed != null && !isBusy ? onPressed : null,
      // The only place a button colour is overridden at a call site. A
      // destructive action is rare enough that a whole theme entry for it would
      // be more indirection than it saves.
      style: FilledButton.styleFrom(
        backgroundColor: context.colors.overdue,
        foregroundColor: context.colors.textOnPrimary,
      ),
      child: _AppButtonContent(
        label: label,
        icon: icon,
        isBusy: isBusy,
        spinnerColor: context.colors.textOnPrimary,
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Shared label/icon/spinner arrangement for the buttons above.
class _AppButtonContent extends StatelessWidget {
  const _AppButtonContent({
    required this.label,
    required this.icon,
    required this.isBusy,
    required this.spinnerColor,
  });

  final String label;
  final IconData? icon;
  final bool isBusy;
  final Color spinnerColor;

  /// Matches the label's line height, so swapping the label for the spinner does
  /// not change the button's height.
  static const double _spinnerSize = 20;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return SizedBox.square(
        dimension: _spinnerSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: spinnerColor,
          // The button already communicates that something is happening; a
          // visible track would add noise inside a small circle.
          backgroundColor: Colors.transparent,
        ),
      );
    }

    if (icon case final IconData iconData) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(iconData, size: 18),
          const SizedBox(width: AppSpacing.sm),
          // Flexible so a long label at a large system font size wraps onto a
          // second line and grows the button, instead of overflowing the row.
          // Wrapping rather than ellipsis on purpose: a user who has turned the
          // font up needs the whole label, not the first two thirds of it.
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      );
    }

    return Text(label, textAlign: TextAlign.center);
  }
}
