import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../../auth/presentation/controllers/current_user_provider.dart';
import '../../data/repositories/supabase_debt_repository.dart';
import '../../domain/entities/debt_direction.dart';
import '../../domain/entities/debt_summary.dart';
import '../../domain/entities/debt_with_status.dart';
import '../../domain/repositories/debt_repository.dart';

/// The debt repository.
///
/// Exposed as the abstract contract rather than the implementation, so a test
/// overrides it with a fake and nothing above this line learns that Supabase
/// exists.
final Provider<DebtRepository> debtRepositoryProvider =
    Provider<DebtRepository>(
      (Ref ref) => SupabaseDebtRepository(ref.watch(supabaseClientProvider)),
    );

/// Every open debt the signed-in user has, both directions, soonest first.
///
/// Empty rather than an error when signed out: there is nothing to fetch, and a
/// request made before there is an account to make it for can only fail. The
/// same guard `subscriptionsProvider` uses, for the same reason.
final FutureProvider<List<DebtWithStatus>> debtsProvider =
    FutureProvider<List<DebtWithStatus>>((Ref ref) async {
      if (ref.watch(currentUserProvider).value == null) {
        return const <DebtWithStatus>[];
      }

      return ref.watch(debtRepositoryProvider).fetchDebts();
    });

/// One side of the ledger.
///
/// Filtered from [debtsProvider] rather than fetched with a `direction` query.
/// Two screens each running their own request would be two round trips for one
/// list and two things to invalidate after every write — and the whole list is a
/// handful of rows.
///
/// The repository still takes a `direction`, because a future screen that only
/// ever wants one side should not have to pull both over the wire to get it.
final debtsByDirectionProvider =
    Provider.family<List<DebtWithStatus>, DebtDirection>((
      Ref ref,
      DebtDirection which,
    ) {
      final List<DebtWithStatus> all =
          ref.watch(debtsProvider).value ?? const <DebtWithStatus>[];

      return all
          .where((DebtWithStatus each) => each.direction == which)
          .toList(growable: false);
    });

/// One debt, by id.
///
/// A family rather than a lookup in the list, because a screen reached by a deep
/// link has no list to look in — and reading the row directly is what makes it
/// open on what the database currently holds rather than on what a list was
/// showing minutes ago.
final debtProvider = FutureProvider.family<DebtWithStatus?, String>(
  (Ref ref, String id) => ref.watch(debtRepositoryProvider).fetchDebt(id),
);

/// Where the user stands on utang, both directions at once.
///
/// Derived rather than fetched. The figures are a pure function of the list, so
/// a provider that recomputed them from its own query would be a second source
/// for the same fact — and the two would disagree for as long as one was stale.
final Provider<DebtSummary> debtSummaryProvider = Provider<DebtSummary>(
  (Ref ref) => DebtSummary.of(
    ref.watch(debtsProvider).value ?? const <DebtWithStatus>[],
  ),
);
