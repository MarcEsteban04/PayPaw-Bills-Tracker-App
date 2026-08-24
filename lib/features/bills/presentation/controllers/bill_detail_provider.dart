import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/bill_with_status.dart';
import 'bill_repository_provider.dart';

/// Whether the list includes bills the user has archived.
///
/// Off by default, because archiving means "stop showing me this". It exists at
/// all because without it archiving is a one-way trip: the drawer offers Restore,
/// but an archived bill cannot be reached to open its drawer, and the undo
/// snackbar is gone in seconds. A soft delete you cannot undo is a hard delete
/// wearing a friendlier word.
///
/// Sprint 28 folds this into the real filters. Until then it is one switch.
class ShowArchived extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final NotifierProvider<ShowArchived, bool> showArchivedProvider =
    NotifierProvider<ShowArchived, bool>(ShowArchived.new);

/// Every bill the signed-in user has, soonest due first.
///
/// A `FutureProvider` rather than a stream. Realtime is a Supabase channel, a
/// subscription to manage and a reconnect path to get right, and none of it earns
/// its place while the only writer is this device — the screens that write
/// invalidate this instead. Revisit when bills can change from elsewhere: shared
/// bills in Sprint 75, or recurring generation running server-side in Phase 6.
///
/// Watching [showArchivedProvider] rather than taking a parameter: flipping the
/// switch should refetch, and a family keyed on a bool would keep two independent
/// caches that a write has to invalidate separately.
final FutureProvider<List<BillWithStatus>> billsProvider =
    FutureProvider<List<BillWithStatus>>(
      (Ref ref) => ref
          .watch(billRepositoryProvider)
          .fetchBills(includeArchived: ref.watch(showArchivedProvider)),
    );

/// One bill, by id.
///
/// A family rather than a lookup in [billsProvider]'s list, because a detail or
/// edit screen reached by a deep link has no list to look in — and reading the
/// row directly is what makes the form open on what the database currently holds
/// rather than on what a list was showing minutes ago.
final billDetailProvider = FutureProvider.family<BillWithStatus?, String>(
  (Ref ref, String id) => ref.watch(billRepositoryProvider).fetchBill(id),
);
