import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/calendar_month.dart';

/// Which month is shown, and how to get to another one.
///
/// ## Why "Today" is a button and not always there
///
/// Stepping four months forward and finding no way back but four taps is the
/// standard way a calendar wastes somebody's time. The button appears only when
/// it would do something — on today's own month it would be a control that
/// visibly does nothing, which teaches the user to stop reading the row.
///
/// ## The year is shown, always
///
/// "September" alone is fine until somebody has stepped far enough to be in the
/// next one, and that is exactly when the heading matters. It is the cheapest
/// possible defence against acting on the wrong month.
class MonthNavigator extends StatelessWidget {
  const MonthNavigator({
    required this.month,
    required this.isOnToday,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    super.key,
  });

  final CalendarMonth month;

  /// Whether [month] is the month today falls in.
  final bool isOnToday;

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String label = DateFormat.yMMMM().format(month.first);

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (!isOnToday)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: TextButton(onPressed: onToday, child: const Text('Today')),
          ),
        _StepButton(
          icon: Icons.chevron_left_rounded,
          // Named by what it does, not by where it points. "Previous" on its own
          // is meaningless read aloud in a row of arrows.
          tooltip: 'Previous month',
          onPressed: onPrevious,
        ),
        const SizedBox(width: AppSpacing.xs),
        _StepButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next month',
          onPressed: onNext,
        ),
      ],
    );
  }
}

/// One arrow.
///
/// Its own widget rather than an `IconButton` so the two are the same size
/// whatever the theme does to icon buttons, and so the tap target stays at 44dp
/// while the visible circle stays smaller than that.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.round,
            side: colors.surfaceBorder == null
                ? BorderSide.none
                : BorderSide(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: 22, color: colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
