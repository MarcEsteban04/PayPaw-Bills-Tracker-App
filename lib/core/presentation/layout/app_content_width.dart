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
/// ## Two constructors, and why
///
/// The default fills the height it is given, which is what a screen body wants.
///
/// [AppContentWidth.hugHeight] instead sizes itself to its child. Use it for
/// anything laid out with **loose** constraints — most importantly a
/// `Scaffold.bottomNavigationBar`, which is measured with a maximum height of
/// the whole screen. A height-filling `Align` in that slot expands to the full
/// screen and pins its child to the top of it, which puts the navigation bar at
/// the top of the display and leaves an invisible full-screen box swallowing
/// every tap. That is not a hypothetical: it shipped in Sprint 9 and was found
/// in Sprint 10.
class AppContentWidth extends StatelessWidget {
  /// Fills the available height. For screen bodies.
  const AppContentWidth({
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    super.key,
  }) : _hugHeight = false;

  /// Sizes to the child's height. For loosely-constrained slots such as
  /// `Scaffold.bottomNavigationBar`.
  const AppContentWidth.hugHeight({
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    super.key,
  }) : _hugHeight = true;

  final Widget child;

  /// Widest the child may get. Defaults to [AppBreakpoints.maxContentWidth].
  final double maxWidth;

  final bool _hugHeight;

  @override
  Widget build(BuildContext context) {
    return Align(
      // Top rather than centre when filling: vertical centring would leave a
      // scrollable screen's content floating away from the app bar on a tall
      // window.
      alignment: _hugHeight ? Alignment.bottomCenter : Alignment.topCenter,
      heightFactor: _hugHeight ? 1 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
