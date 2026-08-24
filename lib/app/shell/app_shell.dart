import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/presentation/layout/app_breakpoints.dart';
import '../../core/presentation/layout/app_content_width.dart';
import '../../core/theme/app_palette.dart';
import 'paypaw_bottom_nav.dart';

/// The frame around PayPaw's four primary destinations.
///
/// Each tab keeps its own navigation stack, so pushing a bill detail inside
/// Bills and then switching to Calendar and back returns to that detail rather
/// than to the list. That is what `StatefulShellRoute.indexedStack` provides,
/// and it is the reason the tabs are a shell route rather than four top-level
/// routes.
///
/// `extendBody` is on because the navigation bar floats over the content, as it
/// does in the reference design. Scrollable screens must pad their bottom by
/// `AppSpacing.bottomNavClearance` so their last item is not left underneath it.
///
/// Both the content and the navigation are width-capped here, so a screen
/// written for a phone behaves on a tablet or a foldable without knowing it is
/// on one.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  /// Supplied by go_router; renders the active branch and owns branch state.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: <Widget>[
          AppContentWidth(child: navigationShell),
          // Content dissolves into the canvas before it reaches the bar.
          //
          // The bar floats over the page, so a long screen's content passes
          // underneath it and is cut off by the screen edge. That was always
          // true and always faintly odd; once cards gained a visible outline it
          // became a stray band, with the card's left and right edges poking out
          // either side of the pill and reading as a second bar.
          //
          // A fade rather than more bottom padding: padding only moves where the
          // content *stops*, and content still travels under the bar on the way
          // there. This makes the last few points of the page fade out, which is
          // what a floating bar is supposed to look like.
          const Positioned(left: 0, right: 0, bottom: 0, child: _BottomFade()),
        ],
      ),
      // hugHeight: the bottom slot is measured with loose constraints, so a
      // height-filling wrapper here would put the bar at the top of the screen.
      bottomNavigationBar: AppContentWidth.hugHeight(
        maxWidth: AppBreakpoints.maxNavWidth,
        child: PayPawBottomNav(
          currentIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
        ),
      ),
    );
  }

  void _onDestinationSelected(int index) {
    // Tapping the tab you are already on pops that branch back to its root,
    // which is the behaviour users expect from a bottom navigation bar.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

/// The gradient that lets a scrolling page fade out under the navigation bar.
///
/// Transparent at the top, the canvas at the bottom. It fades to `canvasEnd`
/// because that is the stop the background is nearest by the time it reaches the
/// bottom of the screen — in dark mode all three stops are black, so it is exact
/// there and close enough in light.
///
/// [IgnorePointer] matters: this covers the foot of every screen, and
/// without it a card sitting at the foot of a list would stop being tappable.
class _BottomFade extends StatelessWidget {
  const _BottomFade();

  /// How far above the bar the dissolve begins.
  ///
  /// Short on purpose. At 96 the gradient reached a card sitting clear of the
  /// bar and visibly dimmed it — content nowhere near the edge looking like it
  /// was fading for no reason. This is just enough that a card crossing the
  /// boundary dissolves rather than being cut off.
  static const double _dissolve = 56;

  @override
  Widget build(BuildContext context) {
    final Color canvas = context.colors.canvasEnd;

    // Measured from the bar's own geometry rather than guessed at.
    //
    // The first attempt used `bottomNavClearance` — 96 — as the whole height,
    // which is shorter than the bar actually reaches once the gesture inset and
    // the floating margin are added. The top of the pill sat *above* the fade,
    // so the card behind it still showed either side. This puts full opacity
    // exactly at the bar's top edge, on any device inset.
    final double barTop =
        MediaQuery.paddingOf(context).bottom +
        PayPawBottomNav.floatingMargin +
        PayPawBottomNav.barHeight;
    final double height = barTop + _dissolve;

    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[canvas.withValues(alpha: 0), canvas, canvas],
              // Clear at the top, canvas by the time it reaches the bar, and
              // canvas the rest of the way down. The third stop is what makes
              // the region behind the bar solid rather than still fading.
              stops: <double>[0, _dissolve / height, 1],
            ),
          ),
        ),
      ),
    );
  }
}
