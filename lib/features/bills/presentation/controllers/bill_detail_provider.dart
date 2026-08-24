import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/bill_with_status.dart';
import 'bill_repository_provider.dart';

/// Every bill the signed-in user has, soonest due first.
///
/// A `FutureProvider` rather than a stream. Realtime is a Supabase channel, a
/// subscription to manage and a reconnect path to get right, and none of it earns
/// its place while the only writer is this device — the screens that write
/// invalidate this instead. Revisit when bills can change from elsewhere: shared
/// bills in Sprint 75, or recurring generation running server-side in Phase 6.
final FutureProvider<List<BillWithStatus>> billsProvider =
    FutureProvider<List<BillWithStatus>>(
      (Ref ref) => ref.watch(billRepositoryProvider).fetchBills(),
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
