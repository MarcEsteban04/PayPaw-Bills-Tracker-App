import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../data/repositories/supabase_bill_repository.dart';
import '../../domain/repositories/bill_repository.dart';

/// The bill repository.
///
/// Exposed as the abstract contract rather than the implementation, so a test
/// overrides it with a fake and nothing above this line learns that Supabase
/// exists.
final Provider<BillRepository> billRepositoryProvider =
    Provider<BillRepository>(
      (Ref ref) => SupabaseBillRepository(ref.watch(supabaseClientProvider)),
    );
