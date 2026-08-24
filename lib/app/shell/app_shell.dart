import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/presentation/layout/app_breakpoints.dart';
import '../../core/presentation/layout/app_content_width.dart';
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
      // The body stops above the navigation bar; it does not run under it.
      //
      // `extendBody: true` was how the reference's floating bar was reproduced,
      // and for four tabs of short screens it was invisible. On a screen long
      // enough to scroll it is not: content passes beneath the bar and is cut
      // off by the edge of the display, and because the bar hugs its content
      // the card behind it shows either side of the pill — which reads as a
      // second bar rather than as more page.
      //
      // A gradient that faded content out before the bar was tried first and was
      // worse: it dimmed cards that were nowhere near the bar, and hid the one
      // below them outright. The honest fix is not to overlap in the first
      // place. The bar still floats — it has its own margin and rounded ends,
      // with the canvas visible around it — it simply reserves its own space.
      body: AppContentWidth(child: navigationShell),
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
