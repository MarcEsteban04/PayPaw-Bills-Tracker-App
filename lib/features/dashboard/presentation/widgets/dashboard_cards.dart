import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/domain/money.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';

/// A money figure that counts to its new value when it changes.
///
/// ## It animates on change, never on arrival
///
/// A total that counts up from zero every time the app opens is a loading
/// animation pretending to be information — it delays the one number the reader
/// came for, on a screen that already had it.
///
/// This runs only when the figure *moves*, which on this screen means the user
/// did something: recorded a payment, added a bill. Then the count is worth the
/// half-second, because it is the app showing the effect of their action rather
/// than silently redrawing. `TweenAnimationBuilder` gives exactly that — a tween
/// with no `begin` settles on `end` for the first build and animates from the
/// current value on every one after.
///
/// Whole minor units only. Tweening a `Money` would mean inventing addition on a
/// value object for the sake of an animation; the interpolation is a double, and
/// only the endpoints are ever real amounts.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney({
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 450),
    super.key,
  });

  final Money value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.minorUnits.toDouble()),
      duration: duration,
      // Fast out of the old figure, slow into the new one, so the value the
      // reader ends up with is the one they spend the time looking at.
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double minorUnits, _) => Text(
        Money(
          minorUnits: minorUnits.round(),
          currency: value.currency,
        ).format(),
        maxLines: 1,
        style: style,
      ),
    );
  }
}

/// The dashboard's own surface.
///
/// Not `AppCard`: that one is the list-row card — tighter radius, tighter
/// padding, built to repeat down a page. These are panels, and a dashboard made
/// of list rows reads as a list.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.panel,
        boxShadow: colors.cardShadow,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A heading above a panel's contents.
class DashboardCardTitle extends StatelessWidget {
  const DashboardCardTitle({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle case final String line) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            line,
            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
        ],
      ],
    );
  }
}

/// One figure with a label and an icon.
///
/// Two of these sit side by side under the hero. They answer "when", which the
/// headline cannot: ₱5,500 outstanding is a different month depending on whether
/// it all lands in three weeks or spreads over six.
class DashboardStat extends StatelessWidget {
  const DashboardStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    this.caption,
    super.key,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return DashboardCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadii.xs),
              ),
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            label.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: colors.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: textTheme.titleLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (caption case final String line) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// One cell of the summary grid: a dot, a label, and a figure.
///
/// Flatter than [DashboardStat] on purpose — four of these share one card, and
/// four boxed cards inside a card is a border for every number.
class SummaryFigure extends StatelessWidget {
  const SummaryFigure({
    required this.label,
    required this.value,
    required this.tint,
    this.caption,
    super.key,
  });

  final String label;
  final String value;
  final String? caption;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: textTheme.titleLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (caption case final String line) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(color: colors.textTertiary),
          ),
        ],
      ],
    );
  }
}

/// A ring showing how much of what was billed has been settled.
///
/// The reference design's donut, applied to the question this app answers. Drawn
/// rather than pulled from a package: it is two arcs and a label, and a chart
/// dependency would bring its own colours, its own text styles and its own
/// opinions about animation.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.fraction,
    required this.caption,
    this.size = 96,
    super.key,
  });

  /// 0 to 1. Clamped, because an overpaid bill can push a total past its own
  /// denominator and a ring that wraps twice reads as zero.
  final double fraction;

  /// The number in the middle. Short — this is a hole in a ring, not a card.
  final String caption;

  final double size;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double target = fraction.clamp(0.0, 1.0);

    return Semantics(
      label: 'Settled',
      // The target, not the frame. A screen reader should be told where the ring
      // is going, not read out a sweep it cannot see.
      value: '${(target * 100).round()} percent',
      child: SizedBox(
        width: size,
        height: size,
        // Sweeps to its new fraction when it changes, and settles straight onto
        // it on the first build — the same rule as [AnimatedMoney], for the same
        // reason. Recording a payment is the moment this is worth watching; app
        // launch is not.
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: target),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double value, Widget? child) =>
              CustomPaint(
                painter: _RingPainter(
                  fraction: value,
                  // `border`, not `surfaceMuted`: this ring sits on a white card,
                  // and the muted token is close enough to white that the track
                  // read as a faint smudge rather than as the other half of the
                  // figure.
                  track: colors.border,
                  // The brand green, at full strength. This is the one place on
                  // the dashboard where green means "done" rather than "press
                  // me", and the ring is unmistakably not a button.
                  fill: colors.primary,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${(value * 100).round()}%',
                        style: textTheme.titleMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      // Rebuilt on every frame above, but this does not change —
                      // handed through as the builder's `child` so the caption is
                      // laid out once rather than sixty times a second.
                      ?child,
                    ],
                  ),
                ),
              ),
          child: Text(
            caption,
            style: textTheme.labelSmall?.copyWith(color: colors.textTertiary),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.track,
    required this.fill,
  });

  final double fraction;
  final Color track;
  final Color fill;

  static const double _stroke = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Rect arc = bounds.deflate(_stroke / 2);

    final Paint trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arc, 0, math.pi * 2, false, trackPaint);

    if (fraction <= 0) {
      return;
    }

    canvas.drawArc(
      arc,
      // From the top, clockwise, the way every progress dial does.
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.fill != fill || old.track != track;
}

/// One band of a stacked horizontal bar.
@immutable
class BandSlice {
  const BandSlice({
    required this.share,
    required this.color,
    required this.label,
  });

  final double share;
  final Color color;
  final String label;
}

/// A stacked bar, for a breakdown that is a set of parts of one whole.
///
/// A bar rather than a pie. At a glance a reader compares lengths far better than
/// angles, and a bar keeps working when one slice is two per cent — which a pie
/// turns into an unlabelled sliver. It also fits the width a card already has,
/// where a pie needs a square.
class StackedBar extends StatelessWidget {
  const StackedBar({required this.slices, this.height = 14, super.key});

  final List<BandSlice> slices;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    if (slices.isEmpty) {
      return SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: AppRadii.round,
          ),
          child: const SizedBox(width: double.infinity),
        ),
      );
    }

    return ClipRRect(
      borderRadius: AppRadii.round,
      child: SizedBox(
        height: height,
        child: Row(
          // Stretch, not the default centre. `Row` gives its children a *loose*
          // cross-axis constraint, and a `ColoredBox` with no child takes the
          // smallest size it is allowed — which is zero height. The bar drew
          // nothing at all, and the card showed a band of empty white where the
          // chart should have been.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final BandSlice slice in slices)
              Expanded(
                // Flex takes an int, so the share is scaled up before rounding.
                // A slice below a thousandth would round to zero and vanish; one
                // is the floor, which keeps it a hairline rather than nothing.
                flex: math.max(1, (slice.share * 1000).round()),
                child: Semantics(
                  label: slice.label,
                  child: ColoredBox(color: slice.color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The key beneath a breakdown: a dot, a name, and what it is worth.
class BreakdownLegend extends StatelessWidget {
  const BreakdownLegend({required this.rows, super.key});

  final List<LegendRow> rows;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        for (final LegendRow row in rows) ...<Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: row.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  row.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                row.percent,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                row.amount,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (row != rows.last) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

@immutable
class LegendRow {
  const LegendRow({
    required this.color,
    required this.label,
    required this.percent,
    required this.amount,
  });

  final Color color;
  final String label;
  final String percent;
  final String amount;
}

/// One column of the months chart.
@immutable
class MonthBar {
  const MonthBar({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.isCurrent,
  });

  final String label;
  final String amount;

  /// Height as a share of the tallest bar, 0 to 1.
  final double fraction;

  /// The month being lived through, which gets the accent.
  final bool isCurrent;
}

/// What falls due over the next few months.
///
/// Columns rather than a line: these are discrete buckets, and a line between
/// them would draw a trend through months that have no relationship to each
/// other. A month with nothing due still gets a column so the axis keeps its
/// shape — an empty slot is information.
class MonthlyDueChart extends StatelessWidget {
  const MonthlyDueChart({required this.bars, this.height = 132, super.key});

  final List<MonthBar> bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final MonthBar bar in bars)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: Semantics(
                  label: '${bar.label}: ${bar.amount}',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: LayoutBuilder(
                          builder:
                              (BuildContext context, BoxConstraints limits) {
                                // A visible floor, so an empty month reads as a
                                // month with nothing in it rather than as a gap
                                // where a bar failed to draw.
                                final double tall = math.max(
                                  4,
                                  limits.maxHeight * bar.fraction,
                                );

                                return Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    height: tall,
                                    decoration: BoxDecoration(
                                      color: bar.isCurrent
                                          ? colors.primary
                                          : colors.primary.withValues(
                                              alpha: 0.22,
                                            ),
                                      borderRadius: AppRadii.round,
                                    ),
                                  ),
                                );
                              },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        bar.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: bar.isCurrent
                              ? colors.textPrimary
                              : colors.textTertiary,
                          fontWeight: bar.isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
