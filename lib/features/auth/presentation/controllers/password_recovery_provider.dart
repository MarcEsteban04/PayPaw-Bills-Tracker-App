import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../data/repositories/supabase_auth_repository.dart';

/// Counts password reset links opened on this device.
///
/// A counter rather than `Stream<void>`, and that is not cosmetic: `ref.listen`
/// compares states with `==`, and two `AsyncData<void>` values are equal. A
/// second reset in the same session would emit an identical state and no
/// listener would run. An incrementing count is always a new value.
///
/// Watched globally rather than by a screen: the link can arrive while the app is
/// anywhere, or can be what launched it.
final StreamProvider<int> passwordRecoveryProvider = StreamProvider<int>((
  Ref ref,
) {
  // Nothing to listen for without a backend, and reading the repository would
  // throw.
  if (!ref.watch(isBackendConfiguredProvider)) {
    return const Stream<int>.empty();
  }

  int opened = 0;

  return ref
      .watch(authRepositoryProvider)
      .passwordRecoveryRequests()
      .map((_) => ++opened);
});
