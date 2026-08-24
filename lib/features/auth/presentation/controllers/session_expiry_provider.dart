import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../data/repositories/supabase_auth_repository.dart';

/// Counts sessions that ended without the user asking.
///
/// A counter for the same reason `passwordRecoveryProvider` is one: `ref.listen`
/// compares states with `==`, so two `AsyncData<void>` values are equal and a
/// second expiry would never reach a listener.
final StreamProvider<int> sessionExpiryProvider = StreamProvider<int>((
  Ref ref,
) {
  if (!ref.watch(isBackendConfiguredProvider)) {
    return const Stream<int>.empty();
  }

  int expiries = 0;

  return ref
      .watch(authRepositoryProvider)
      .sessionExpirations()
      .map((_) => ++expiries);
});
