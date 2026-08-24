import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../recurring/presentation/controllers/recurring_bill_providers.dart';
import '../../domain/entities/bill_filter.dart';
import '../../domain/entities/bill_with_status.dart';
import 'bill_filter_controller.dart';
import 'bill_repository_provider.dart';

/// Every bill the signed-in user has, soonest due first.
///
/// A `FutureProvider` rather than a stream. Realtime is a Supabase channel, a
/// subscription to manage and a reconnect path to get right, and none of it earns
/// its place while the only writer is this device — the screens that write
/// invalidate this instead. Revisit when bills can change from elsewhere: shared
/// bills in Sprint 75, or recurring generation running server-side in Phase 6.
///
/// **Every row, archived included.** [filteredBillsProvider] narrows it, and
/// `BillFilter` leaves archived bills out by default — so the fetch does not have
/// to.
///
/// This used to pass `includeArchived` from the filter, which kept those rows on
/// the server until something asked for them. It also meant a user whose only
/// bills were archived saw "No bills yet" with no filter bar rendered, and so no
/// way to ask: the screen was in a state it could not get out of. Fetching them
/// always costs a handful of rows on one person's list, and there is one rule
/// instead of a rule and a fetch flag that have to agree.
final FutureProvider<List<BillWithStatus>>
billsProvider = FutureProvider<List<BillWithStatus>>((Ref ref) async {
  // Generation first, so a template saved a moment ago has its occurrences in
  // this very list rather than appearing after the next restart.
  //
  // Awaited, not fired and forgotten: fetching before it finishes would show
  // a list that is correct and then silently grows. The call is cached for
  // the session, so a pull-to-refresh does not pay for it again, and it
  // cannot fail the screen — see [billGenerationProvider].
  await ref.watch(billGenerationProvider.future);

  return ref.watch(billRepositoryProvider).fetchBills(includeArchived: true);
});

/// The bills the current filter admits, in the order it asks for.
///
/// A plain `Provider` over [billsProvider]'s `AsyncValue` rather than its own
/// `FutureProvider`: filtering is synchronous and local, so making it async would
/// hand the screen a second loading state for work that takes no time — and the
/// list would flash empty on every keystroke.
final Provider<AsyncValue<List<BillWithStatus>>> filteredBillsProvider =
    Provider<AsyncValue<List<BillWithStatus>>>((Ref ref) {
      final BillFilter filter = ref.watch(billFilterProvider);

      return ref
          .watch(billsProvider)
          .whenData((List<BillWithStatus> all) => filter.apply(all));
    });

/// One bill, by id.
///
/// A family rather than a lookup in [billsProvider]'s list, because a detail or
/// edit screen reached by a deep link has no list to look in — and reading the
/// row directly is what makes the form open on what the database currently holds
/// rather than on what a list was showing minutes ago.
final billDetailProvider = FutureProvider.family<BillWithStatus?, String>(
  (Ref ref, String id) => ref.watch(billRepositoryProvider).fetchBill(id),
);
