import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:paypaw/features/auth/domain/entities/authenticated_user.dart';
import 'package:paypaw/features/auth/domain/entities/sign_up_outcome.dart';
import 'package:paypaw/features/auth/presentation/controllers/sign_up_controller.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  ProviderContainer containerWith(FakeAuthRepository repository) {
    final ProviderContainer container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    return container;
  }

  test('starts with nothing submitted', () {
    final ProviderContainer container = containerWith(FakeAuthRepository());

    expect(container.read(signUpControllerProvider).value, isNull);
    expect(container.read(signUpControllerProvider).hasError, isFalse);
  });

  test('reports that a confirmation email is needed', () async {
    final ProviderContainer container = containerWith(
      FakeAuthRepository(
        outcome: const SignUpNeedsConfirmation(email: 'marc@example.com'),
      ),
    );

    await container
        .read(signUpControllerProvider.notifier)
        .submit(email: 'marc@example.com', password: 'paypaw2026');

    expect(
      container.read(signUpControllerProvider).value,
      isA<SignUpNeedsConfirmation>().having(
        (SignUpNeedsConfirmation outcome) => outcome.email,
        'email',
        'marc@example.com',
      ),
    );
  });

  test('reports being signed in when confirmation is disabled', () async {
    final ProviderContainer container = containerWith(
      FakeAuthRepository(
        outcome: const SignUpSignedIn(
          user: AuthenticatedUser(
            id: 'abc',
            email: 'marc@example.com',
            hasConfirmedEmail: true,
          ),
        ),
      ),
    );

    await container
        .read(signUpControllerProvider.notifier)
        .submit(email: 'marc@example.com', password: 'paypaw2026');

    expect(
      container.read(signUpControllerProvider).value,
      isA<SignUpSignedIn>(),
    );
  });

  test('passes the credentials through untouched', () async {
    final FakeAuthRepository repository = FakeAuthRepository();
    final ProviderContainer container = containerWith(repository);

    await container
        .read(signUpControllerProvider.notifier)
        .submit(email: 'marc@example.com', password: ' paypaw2026 ');

    expect(repository.lastEmail, 'marc@example.com');
    // Whitespace intact: trimming a password would lock the user out of the
    // account they just created. Trimming the email is the repository's job.
    expect(repository.lastPassword, ' paypaw2026 ');
  });

  test('captures a failure rather than throwing', () async {
    final ProviderContainer container = containerWith(
      FakeAuthRepository(
        error: const ValidationException(
          message: 'That email is already registered.',
        ),
      ),
    );

    await container
        .read(signUpControllerProvider.notifier)
        .submit(email: 'marc@example.com', password: 'paypaw2026');

    final AsyncValue<SignUpOutcome?> state = container.read(
      signUpControllerProvider,
    );

    expect(state.hasError, isTrue);
    expect(state.error, isA<ValidationException>());
  });

  test('ignores a second submit while one is in flight', () async {
    final FakeAuthRepository repository = FakeAuthRepository(
      delay: const Duration(milliseconds: 50),
    );
    final ProviderContainer container = containerWith(repository);
    final SignUpController controller = container.read(
      signUpControllerProvider.notifier,
    );

    // Not awaited: this is the double-tap the button's busy state is also
    // guarding against. Two accounts from one tap-tap is not recoverable.
    final Future<void> first = controller.submit(
      email: 'marc@example.com',
      password: 'paypaw2026',
    );
    final Future<void> second = controller.submit(
      email: 'marc@example.com',
      password: 'paypaw2026',
    );
    await Future.wait<void>(<Future<void>>[first, second]);

    expect(repository.signUpCalls, 1);
  });

  test('clearing an error returns the form to its initial state', () async {
    final ProviderContainer container = containerWith(
      FakeAuthRepository(error: const ServerException()),
    );
    final SignUpController controller = container.read(
      signUpControllerProvider.notifier,
    );

    await controller.submit(email: 'marc@example.com', password: 'paypaw2026');
    expect(container.read(signUpControllerProvider).hasError, isTrue);

    controller.clearError();

    expect(container.read(signUpControllerProvider).hasError, isFalse);
    expect(container.read(signUpControllerProvider).value, isNull);
  });

  test('clearing does not discard a successful result', () async {
    final ProviderContainer container = containerWith(FakeAuthRepository());
    final SignUpController controller = container.read(
      signUpControllerProvider.notifier,
    );

    await controller.submit(email: 'marc@example.com', password: 'paypaw2026');
    controller.clearError();

    // The confirmation screen must not be wiped by a stray clear.
    expect(container.read(signUpControllerProvider).value, isNotNull);
  });
}
