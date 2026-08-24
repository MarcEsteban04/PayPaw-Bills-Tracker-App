import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

/// Shows a PayPaw bottom sheet.
///
/// Surface, radius and drag handle come from the theme. This function adds the
/// parts that are easy to forget and awkward to debug:
///
/// * `isScrollControlled`, so a sheet containing a form can grow past half the
///   screen instead of being clipped;
/// * bottom padding for the keyboard inset, so a focused field is not hidden
///   behind the keyboard;
/// * bottom padding for the safe area, so the last control clears the gesture
///   bar.
///
/// Returns whatever the sheet is popped with, or null if it was dismissed.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  bool isDismissible = true,
  bool useSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    useSafeArea: useSafeArea,
    // The root navigator, not the tab's.
    //
    // A screen inside the shell sits under a nested navigator, and a sheet shown
    // there is only modal over that branch — the floating navigation bar and the
    // add button beside it keep drawing on top of it. On the bill detail sheet
    // that put the pill squarely over the Delete button, which was simply
    // unreachable.
    //
    // A modal sheet is modal over the app or it is not modal.
    useRootNavigator: true,
    builder: (BuildContext context) => _SheetBody(title: title, child: child),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenInset,
        right: AppSpacing.screenInset,
        // Lifts the sheet above the keyboard when a field inside it has focus.
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title case final String sheetTitle) ...<Widget>[
            Text(
              sheetTitle,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          // Flexible, not the child on its own.
          //
          // `isScrollControlled` offers the sheet the whole screen height, and
          // `mainAxisSize.min` then asks the child how tall it wants to be. A
          // scrolling child — a `ListView`, even a shrink-wrapping one — answers
          // with its full content height, and a list of thirteen categories is
          // taller than the room a title and the insets leave. The result was a
          // sheet overflowing its own bottom by a few pixels and painting the
          // yellow-and-black stripe over the last row.
          //
          // Flexible caps it at what is actually left, and the child scrolls
          // inside that. A short sheet still hugs its content, because Flexible
          // is a maximum and not a demand.
          Flexible(child: child),
        ],
      ),
    );
  }
}
