import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../data/repositories/supabase_recurring_bill_repository.dart';
import '../../domain/entities/recurring_bill.dart';
import '../../domain/repositories/recurring_bill_repository.dart';

/// The recurring bill repository.
final Provider<RecurringBillRepository> recurringBillRepositoryProvider =
    Provider<RecurringBillRepository>(
      (Ref ref) =>
          SupabaseRecurringBillRepository(ref.watch(supabaseClientProvider)),
    );

/// Every recurring template the user has.
final FutureProvider<List<RecurringBill>> recurringBillsProvider =
    FutureProvider<List<RecurringBill>>(
      (Ref ref) =>
          ref.watch(recurringBillRepositoryProvider).fetchRecurringBills(),
    );

/// Asks the server to materialise anything due, once per app run.
///
/// ## Once, not on every rebuild
///
/// A `FutureProvider` caches its result for as long as something is listening, so
/// the round trip happens when the bills screen first appears and not again until
/// something invalidates it. Saving a new template does exactly that.
///
/// ## It never fails the screen
///
/// Generation is a background courtesy — the scheduled job in the database is the
/// real mechanism. A failure here means "no new bills yet", not "the bills list is
/// broken", so this swallows the error rather than letting an `AsyncError` reach a
/// screen that has perfectly good rows to show. The count is returned so a caller
/// can tell whether refetching is worth it; null means it did not run.
final FutureProvider<int?> billGenerationProvider = FutureProvider<int?>((
  Ref ref,
) async {
  try {
    return await ref.watch(recurringBillRepositoryProvider).generateDueBills();
  } on Object {
    return null;
  }
});
