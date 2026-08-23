import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

import '../../theme/app_radii.dart';

/// A placeholder block that pulses while real content loads.
///
/// Compose these into the shape of what is coming — a title bar, two lines of
/// meta, an amount on the right — inside an `AppCard`. A skeleton that matches
/// the eventual layout means the screen does not jump when the data lands, which
/// a spinner cannot avoid.
///
/// It pulses opacity rather than sweeping a shimmer gradient across itself: a
/// gradient sweep needs a repainting shader per element, and on a list of twenty
/// rows that is real cost for an effect the user sees for half a second.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    this.width,
    this.height = 16,
    this.borderRadius = AppRadii.chip,
    super.key,
  });

  /// Null stretches to the available width.
  final double? width;

  final double height;
  final BorderRadius borderRadius;

  /// A single line of placeholder text.
  factory AppSkeleton.line({double? width}) =>
      AppSkeleton(width: width, height: 14);

  /// A placeholder for a circular avatar or icon.
  factory AppSkeleton.circle({double diameter = 40}) => AppSkeleton(
    width: diameter,
    height: diameter,
    borderRadius: AppRadii.round,
  );

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Excluded from semantics: a screen reader announcing a row of empty
    // placeholder boxes is worse than silence. The screen it sits on should
    // announce that it is loading instead.
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: context.colors.surfaceMuted,
            borderRadius: widget.borderRadius,
          ),
        ),
      ),
    );
  }
}
