import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import '../../../bills/presentation/controllers/bill_detail_provider.dart';
import '../../../bills/presentation/widgets/bill_detail_sheet.dart';
import '../../../subscriptions/domain/entities/subscription.dart';
import '../../../subscriptions/presentation/controllers/subscription_providers.dart';
import '../../../subscriptions/presentation/widgets/subscription_detail_sheet.dart';
import '../../domain/entities/scheduled_notice.dart';
import '../controllers/pending_notice.dart';

/// Opens whatever a tapped notification was about.
///
/// ## Why it sits above the router rather than on a screen
///
/// A notification can be tapped in two states, and they arrive differently. With
/// the app running, the tap reaches a callback and the app is already on some
/// screen — any screen. With the app dead, the tap *starts* the process, and the
/// payload is set in `main()` before a single widget exists.
///
/// A listener on the Bills screen would miss the second case entirely: it is set
/// before that screen is built, and `ref.listen` in a widget has no
/// "fire immediately". Placing this above the router, as a sibling of
/// [SessionExpiryListener], covers both — a `StatefulWidget` catches what was
/// already there in `initState`, and the listener catches everything after.
///
/// ## It navigates first, then opens the drawer
///
/// Both drawers are modal over the whole app, so either would open anywhere.
/// Landing the user on the right screen first means that when they dismiss it
/// they are somewhere that makes sense, rather than back on whatever they were
/// looking at three days ago.
class NoticeListener extends ConsumerStatefulWidget {
  const NoticeListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NoticeListener> createState() => _NoticeListenerState();
}

class _NoticeListenerState extends ConsumerState<NoticeListener> {
  /// Guards against two openings racing.
  ///
  /// The drawer is `await`ed, and a second tap while it is up would stack a
  /// second one on top. Taking the payload clears it, but the fetch in between
  /// is a real gap.
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
    ref.listen(pendingNoticeProvider, (_, String? payload) {
      if (payload != null) {
        _openPending();
      }
    });

    return widget.child;
  }

  void _openPending() {
    final String? payload = ref.read(pendingNoticeProvider.notifier).take();

    if (payload == null || _isOpening) {
      return;
    }

    // Decoded here rather than in the value holder: which screens exist is this
    // widget's business. An unrecognisable payload opens nothing, which is
    // better than guessing and landing somebody on the wrong screen.
    if (NoticeTarget.decode(payload) case (
      final NoticeTargetKind kind,
      final String id,
    )) {
      unawaited(switch (kind) {
        NoticeTargetKind.bill => _openBill(id),
        NoticeTargetKind.subscription => _openSubscription(id),
      });
    }
  }

  Future<void> _openBill(String billId) async {
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

  /// Opens the subscription a trial or renewal notice was about.
  ///
  /// Pushed rather than switched to, because Subscriptions is not a tab — see
  /// `SubscriptionsScreen`. The user lands on the list with a back arrow to
  /// wherever they were, which is the same shape as reaching it from the
  /// dashboard.
  Future<void> _openSubscription(String subscriptionId) async {
    _isOpening = true;

    try {
      if (!mounted) {
        return;
      }
      unawaited(context.pushNamed(AppRoutes.subscriptions.routeName));

      final Subscription? subscription = await ref.read(
        subscriptionProvider(subscriptionId).future,
      );

      if (subscription == null || !mounted) {
        return;
      }

      await showSubscriptionDetailSheet(
        context: context,
        ref: ref,
        subscription: subscription,
        // The device clock. A notice fires against it, so the drawer it opens
        // should compute its trial countdown against the same one — otherwise
        // "starts charging tomorrow" could open onto a sheet saying the trial
        // has a day left, or none.
        today: DateTime.now(),
      );
    } on Object {
      // Same as above: they are on the Subscriptions list, which is where the
      // tap was taking them.
    } finally {
      _isOpening = false;
    }
  }
}
