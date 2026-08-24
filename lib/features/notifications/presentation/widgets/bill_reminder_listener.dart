import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import '../../../bills/presentation/controllers/bill_detail_provider.dart';
import '../../../bills/presentation/widgets/bill_detail_sheet.dart';
import '../controllers/pending_bill_notification.dart';

/// Opens the bill whose reminder was tapped.
///
/// ## Why it sits above the router rather than on the Bills screen
///
/// A reminder can be tapped in two states, and they arrive differently. With the
/// app running, the tap reaches a callback and the app is already on some
/// screen — any screen. With the app dead, the tap *starts* the process, and the
/// id is set in `main()` before a single widget exists.
///
/// A listener on the Bills screen would miss the second case entirely: it is set
/// before that screen is built, and `ref.listen` in a widget has no
/// "fire immediately". Placing this above the router, as a sibling of
/// [SessionExpiryListener], covers both — a `StatefulWidget` catches what was
/// already there in `initState`, and the listener catches everything after.
///
/// ## It navigates first, then opens the drawer
///
/// The drawer is modal over the whole app, so it would open anywhere. Landing
/// the user on Bills first means that when they dismiss it they are on the
/// screen the bill belongs to, rather than back on whatever they were looking at
/// three days ago.
class BillReminderListener extends ConsumerStatefulWidget {
  const BillReminderListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BillReminderListener> createState() =>
      _BillReminderListenerState();
}

class _BillReminderListenerState extends ConsumerState<BillReminderListener> {
  /// Guards against two openings racing.
  ///
  /// The drawer is `await`ed, and a second tap while it is up would stack a
  /// second one on top. Taking the id clears it, but the fetch in between is a
  /// real gap.
  bool _isOpening = false;

  @override
  void initState() {
    super.initState();

    // After the first frame, not during it. The router has no navigator until
    // it has built once, and there is nothing to show a drawer over.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingBillNotificationProvider, (_, String? billId) {
      if (billId != null) {
        _openPending();
      }
    });

    return widget.child;
  }

  void _openPending() {
    final String? billId = ref
        .read(pendingBillNotificationProvider.notifier)
        .take();

    if (billId == null || _isOpening) {
      return;
    }

    unawaited(_open(billId));
  }

  Future<void> _open(String billId) async {
    _isOpening = true;

    try {
      if (!mounted) {
        return;
      }
      context.goNamed(AppRoutes.bills.routeName);

      // Fetched by id rather than found in the loaded list. A reminder can
      // arrive before the list has ever been read — the app may have started
      // seconds ago — and the row is what the drawer needs.
      final BillWithStatus? item = await ref.read(
        billDetailProvider(billId).future,
      );

      // Gone. Deleted, or belonging to a different account now signed in; RLS
      // makes both the same answer. Landing on Bills is the honest outcome and
      // the user is already there.
      if (item == null || !mounted) {
        return;
      }

      await showBillDetailSheet(context: context, item: item);
    } on Object {
      // The bill could not be read. The user is on the Bills screen, which is
      // where they were headed; a toast about a failed lookup they did not ask
      // for would be noise on top of a tap that already did something sensible.
    } finally {
      _isOpening = false;
    }
  }
}
