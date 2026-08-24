import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/core/providers/supabase_providers.dart';
import 'package:paypaw/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:paypaw/features/auth/presentation/controllers/forgot_password_controller.dart';
import 'package:paypaw/features/auth/presentation/controllers/password_recovery_provider.dart';
import 'package:paypaw/features/auth/presentation/controllers/reset_password_controller.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  ProviderContainer containerWith(FakeAuthRepository repository) {
    final ProviderContainer container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    // Registered in this order so the container is disposed before the fake's
    // stream controllers are closed.
    addTearDown(repository.dispose);
    addTearDown(container.dispose);

    return container;
  }

  group('requesting a reset', () {
    test('starts with nothing submitted', () {
      final ProviderContainer container = containerWith(FakeAuthRepository());

      expect(container.read(forgotPasswordControllerProvider).value, isNull);
    });

    test('reports the address it was sent to, trimmed', () async {
      final FakeAuthRepository repository = FakeAuthRepository();
      final ProviderContainer container = containerWith(repository);

      await container
          .read(forgotPasswordControllerProvider.notifier)
          .submit(email: '  marc@example.com  ');

      expect(repository.lastResetEmail, 'marc@example.com');
      expect(
        container.read(forgotPasswordControllerProvider).value,
        'marc@example.com',
      );
    });

    test('captures a rate limit as an error', () async {
      final ProviderContainer container = containerWith(
        FakeAuthRepository(
          error: const ValidationException(
            message: 'Too many attempts. Wait a minute and try again.',
          ),
        ),
      );

      await container
          .read(forgotPasswordControllerProvider.notifier)
          .submit(email: 'marc@example.com');

      expect(container.read(forgotPasswordControllerProvider).hasError, isTrue);
    });

    test('ignores a second submit while one is in flight', () async {
      final FakeAuthRepository repository = FakeAuthRepository(
        delay: const Duration(milliseconds: 50),
      );
      final ProviderContainer container = containerWith(repository);
      final ForgotPasswordController controller = container.read(
        forgotPasswordControllerProvider.notifier,
      );

      await Future.wait<void>(<Future<void>>[
        controller.submit(email: 'marc@example.com'),
        controller.submit(email: 'marc@example.com'),
      ]);

      expect(repository.sendPasswordResetCalls, 1);
    });
  });

  group('recovery links', () {
    ProviderContainer configuredWith(FakeAuthRepository repository) {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          isBackendConfiguredProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(repository.dispose);
      addTearDown(container.dispose);

      return container;
    }

    test('each opened link is a distinct value', () async {
      // The reason this provider counts instead of emitting void: ref.listen
      // compares states with ==, and two identical AsyncData<void> values would
      // never fire a listener twice. A second reset in one session would then
      // open the link and go nowhere.
      final FakeAuthRepository repository = FakeAuthRepository();
      final ProviderContainer container = configuredWith(repository);

      final List<int> seen = <int>[];
      final ProviderSubscription<AsyncValue<int>> subscription = container
          .listen<AsyncValue<int>>(passwordRecoveryProvider, (
            _,
            AsyncValue<int> next,
          ) {
            if (next case AsyncData<int>(value: final int count)) {
              seen.add(count);
            }
          }, fireImmediately: true);
      addTearDown(subscription.close);

      repository.emitPasswordRecovery();
      await Future<void>.delayed(Duration.zero);
      repository.emitPasswordRecovery();
      await Future<void>.delayed(Duration.zero);

      expect(seen, <int>[1, 2]);
    });

    test('emits nothing without a backend', () async {
      final FakeAuthRepository repository = FakeAuthRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          isBackendConfiguredProvider.overrideWithValue(false),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(repository.dispose);
      addTearDown(container.dispose);

      container.listen<AsyncValue<int>>(passwordRecoveryProvider, (_, _) {});
      repository.emitPasswordRecovery();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(passwordRecoveryProvider).value, isNull);
    });
  });

  group('setting a new password', () {
    test('returns the now signed-in user', () async {
      final ProviderContainer container = containerWith(FakeAuthRepository());

      await container
          .read(resetPasswordControllerProvider.notifier)
          .submit(password: 'paypaw2027');

      expect(container.read(resetPasswordControllerProvider).value, isNotNull);
    });

    test('passes the password through untouched', () async {
      final FakeAuthRepository repository = FakeAuthRepository();
      final ProviderContainer container = containerWith(repository);

      await container
          .read(resetPasswordControllerProvider.notifier)
          .submit(password: ' paypaw2027 ');

      expect(repository.lastNewPassword, ' paypaw2027 ');
    });

    test('captures an expired link as an error', () async {
      final ProviderContainer container = containerWith(
        FakeAuthRepository(
          error: const AuthenticationException(
            message:
                'That reset link has expired or was already used. Request a '
                'new one.',
          ),
        ),
      );

      await container
          .read(resetPasswordControllerProvider.notifier)
          .submit(password: 'paypaw2027');

      expect(container.read(resetPasswordControllerProvider).hasError, isTrue);
    });

    test('ignores a second submit while one is in flight', () async {
      // This guard matters more here than anywhere else: the second call would
      // run after the first had already consumed the recovery session, and would
      // fail with "that link expired" on a reset that in fact worked.
      final FakeAuthRepository repository = FakeAuthRepository(
        delay: const Duration(milliseconds: 50),
      );
      final ProviderContainer container = containerWith(repository);
      final ResetPasswordController controller = container.read(
        resetPasswordControllerProvider.notifier,
      );

      await Future.wait<void>(<Future<void>>[
        controller.submit(password: 'paypaw2027'),
        controller.submit(password: 'paypaw2027'),
      ]);

      expect(repository.updatePasswordCalls, 1);
    });
  });
}
