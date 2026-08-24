import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The bill a tapped reminder wants opened, until something opens it.
///
/// ## Why a hand-off and not a route
///
/// A bill's detail is a bottom sheet over the Bills screen, not a page — see
/// `showBillDetailSheet`, and the reasons there. So a notification tap cannot
/// simply navigate to it: there is no URL to navigate *to*.
///
/// This carries the id across the gap instead. The tap sets it and sends the app
/// to Bills; Bills notices, opens the drawer, and clears it. The alternative —
/// inventing a `/bills/:id` route whose only job is to show a sheet and pop —
/// would put a page in the history stack that the back button then has to
/// explain.
///
/// ## It clears on consumption, deliberately
///
/// The id is an *event*, not a fact: "this was tapped", not "this is selected".
/// Left set, it would reopen the drawer every time the user returned to Bills,
/// days after the reminder — which is the same class of bug that made a bill
/// form fail to close in Sprint 25, and it is avoided the same way.
class PendingBillNotification extends Notifier<String?> {
  @override
  String? build() => null;

  /// Records that a reminder for [billId] was tapped.
  void open(String billId) => state = billId;

  /// Takes the pending id, leaving nothing behind.
  ///
  /// Read-and-clear in one call rather than two, so a caller cannot read it,
  /// fail partway, and leave it set for the next screen that looks.
  String? take() {
    final String? billId = state;
    state = null;

    return billId;
  }
}

final NotifierProvider<PendingBillNotification, String?>
pendingBillNotificationProvider =
    NotifierProvider<PendingBillNotification, String?>(
      PendingBillNotification.new,
    );
