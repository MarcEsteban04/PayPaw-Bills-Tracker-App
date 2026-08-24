import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:paypaw/features/auth/domain/entities/authenticated_user.dart';
import 'package:paypaw/features/auth/presentation/controllers/sign_in_controller.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  ProviderContainer containerWith(FakeAuthRepository repository) {
    final ProviderContainer container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    // Registered in this order on purpose. Teardowns run last-registered-first,
    // so the container is disposed before the fake's stream controller is
    // closed. Closing it while the provider still holds a subscription leaves
    // the close future waiting for a listener that is never coming back.
    addTearDown(repository.dispose);
    addTearDown(container.dispose);

    return container;
  }

  test('starts with nothing submitted', () {
    final ProviderContainer container = containerWith(FakeAuthRepository());

    expect(container.read(signInControllerProvider).value, isNull);
  });

  test('returns the signed-in user', () async {
    final ProviderContainer container = containerWith(
      FakeAuthRepository(
        signedInUser: const AuthenticatedUser(
          id: 'user-9',
          email: 'marc@example.com',
          hasConfirmedEmail: true,
        ),
      ),
    );

    await container
        .read(signInControllerProvider.notifier)
        .submit(email: 'marc@example.com', password: 'paypaw2026');

    expect(container.read(signInControllerProvider).value?.id, 'user-9');
  });

  test('trims nothing off the password', () async {
    final FakeAuthRepository repository = FakeAuthRepository();
    final ProviderContainer container = containerWith(repository);

    await container
        .read(signInControllerProvider.notifier)
        .submit(email: 'marc@example.com', password: ' paypaw2026 ');

    expect(repository.lastPassword, ' paypaw2026 ');
  });

  test('captures wrong credentials as an error, not a throw', () async {
    final ProviderContainer container = containerWith(
      FakeAuthRepository(
        error: const AuthenticationException(
          message: 'That email and password do not match an account.',
        ),
      ),
    );

    await container
        .read(signInControllerProvider.notifier)
        .submit(email: 'marc@example.com', password: 'wrong');

    expect(container.read(signInControllerProvider).hasError, isTrue);
    expect(container.read(signInControllerProvider).value, isNull);
  });

  test('ignores a second submit while one is in flight', () async {
    final FakeAuthRepository repository = FakeAuthRepository(
      delay: const Duration(milliseconds: 50),
    );
    final ProviderContainer container = containerWith(repository);
    final SignInController controller = container.read(
      signInControllerProvider.notifier,
    );

    await Future.wait<void>(<Future<void>>[
      controller.submit(email: 'marc@example.com', password: 'paypaw2026'),
      controller.submit(email: 'marc@example.com', password: 'paypaw2026'),
    ]);

    expect(repository.signInCalls, 1);
  });

  test('clearing an error returns the form to its initial state', () async {
    final ProviderContainer container = containerWith(
      FakeAuthRepository(error: const NetworkException()),
    );
    final SignInController controller = container.read(
      signInControllerProvider.notifier,
    );

    await controller.submit(email: 'marc@example.com', password: 'paypaw2026');
    expect(container.read(signInControllerProvider).hasError, isTrue);

    controller.clearError();

    expect(container.read(signInControllerProvider).hasError, isFalse);
  });
}
