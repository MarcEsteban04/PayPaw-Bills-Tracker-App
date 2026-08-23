import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';

/// Caps how wide its child can get, and centres it.
///
/// On a phone this does nothing at all — the child already fits inside the cap,
/// so the widget is invisible in the layout. On a tablet, a foldable, or a
/// desktop window it stops content from stretching into a shape nobody designed:
/// a bill name pinned to the far left and its amount to the far right, with a
/// hand-span of nothing between them.
///
/// Applied once around the shell's content rather than per screen, so a screen
/// written for a phone is automatically fine on a wide window.
class AppContentWidth extends StatelessWidget {
  const AppContentWidth({
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    super.key,
  });

  final Widget child;

  /// Widest the child may get. Defaults to [AppBreakpoints.maxContentWidth].
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      // Top rather than centre: vertical centring would leave a scrollable
      // screen's content floating away from the app bar on a tall window.
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
