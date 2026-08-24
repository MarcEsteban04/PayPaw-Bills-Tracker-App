import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/providers/supabase_providers.dart';
import 'package:paypaw/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:paypaw/features/auth/domain/entities/authenticated_user.dart';
import 'package:paypaw/features/auth/presentation/controllers/current_user_provider.dart';

import '../../helpers/fake_auth_repository.dart';

/// The session stream is what every guard in Sprint 15 will hang off, so its
/// behaviour is worth pinning now: it must answer immediately, and it must keep
/// answering when the session changes without the user asking.
void main() {
  const AuthenticatedUser marc = AuthenticatedUser(
    id: 'user-1',
    email: 'marc@example.com',
    hasConfirmedEmail: true,
  );

  ProviderContainer containerWith(
    FakeAuthRepository repository, {
    bool configured = true,
  }) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        isBackendConfiguredProvider.overrideWithValue(configured),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    // Registered in this order on purpose. Teardowns run last-registered-first,
    // so the container is disposed before the fake's stream controller is
    // closed. Closing it while the provider still holds a subscription leaves
    // the close future waiting for a listener that is never coming back.
    addTearDown(repository.dispose);
    addTearDown(container.dispose);

    return container;
  }

  /// Every value the provider has produced, in order.
  ///
  /// A recorded list rather than `read(provider.future)`: the session stream is a
  /// broadcast stream that never closes, and a test that awaits a future off it
  /// waits for a completion that is never coming.
  List<AuthenticatedUser?> record(ProviderContainer container) {
    final List<AuthenticatedUser?> seen = <AuthenticatedUser?>[];

    final ProviderSubscription<AsyncValue<AuthenticatedUser?>> subscription =
        container.listen<AsyncValue<AuthenticatedUser?>>(currentUserProvider, (
          _,
          AsyncValue<AuthenticatedUser?> next,
        ) {
          if (next case AsyncData<AuthenticatedUser?>(value: final it)) {
            seen.add(it);
          }
        }, fireImmediately: true);
    addTearDown(subscription.close);

    return seen;
  }

  /// Lets the stream deliver whatever is already queued.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('reports signed out when there is no backend', () async {
    // Not an error and not a permanent loading state: an unconfigured app is
    // signed out, which is truthful and keeps every screen above this working.
    final ProviderContainer container = containerWith(
      FakeAuthRepository(initialUser: marc),
      configured: false,
    );

    final List<AuthenticatedUser?> seen = record(container);
    await settle();

    expect(seen, <AuthenticatedUser?>[null]);
  });

  test('starts from the session the SDK already restored', () async {
    final ProviderContainer container = containerWith(
      FakeAuthRepository(initialUser: marc),
    );

    final List<AuthenticatedUser?> seen = record(container);
    await settle();

    // The first value is the restored session, not null — this is what stops an
    // already signed-in user seeing a flash of the sign-in screen on launch.
    expect(seen.first, marc);
  });

  test('starts empty when no session was restored', () async {
    final ProviderContainer container = containerWith(FakeAuthRepository());

    final List<AuthenticatedUser?> seen = record(container);
    await settle();

    expect(seen.first, isNull);
  });

  test('follows a session that ends on its own', () async {
    final FakeAuthRepository repository = FakeAuthRepository(initialUser: marc);
    final ProviderContainer container = containerWith(repository);

    final List<AuthenticatedUser?> seen = record(container);
    await settle();
    expect(seen.first, marc);

    // A refresh token expiring, or the session being revoked from another
    // device. The app has to notice rather than showing a signed-in shell that
    // cannot load anything.
    repository.emitSession(null);
    await settle();

    expect(seen.last, isNull);
  });

  test('follows a sign-in that happens elsewhere', () async {
    final FakeAuthRepository repository = FakeAuthRepository();
    final ProviderContainer container = containerWith(repository);

    final List<AuthenticatedUser?> seen = record(container);
    await settle();

    repository.emitSession(marc);
    await settle();

    expect(seen.last, marc);
  });
}
