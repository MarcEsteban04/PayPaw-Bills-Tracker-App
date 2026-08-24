import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../data/repositories/supabase_payment_repository.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_repository.dart';

/// The payment repository.
///
/// Exposed as the abstract contract rather than the implementation, so a test
/// overrides it with a fake and nothing above this line learns that Supabase
/// exists.
final Provider<PaymentRepository> paymentRepositoryProvider =
    Provider<PaymentRepository>(
      (Ref ref) => SupabasePaymentRepository(ref.watch(supabaseClientProvider)),
    );

/// What has been paid against one bill, most recent first.
///
/// A family keyed on the bill, fetched only when a drawer actually opens. Folding
/// it into the bills list would mean a second query on every list load to render
/// something no row shows — the list already gets its totals from the view.
final paymentsForBillProvider = FutureProvider.family<List<Payment>, String>(
  (Ref ref, String billId) =>
      ref.watch(paymentRepositoryProvider).fetchPaymentsForBill(billId),
);
