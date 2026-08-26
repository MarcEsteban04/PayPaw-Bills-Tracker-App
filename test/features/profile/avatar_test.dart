import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/auth/domain/entities/authenticated_user.dart';
import 'package:paypaw/features/auth/presentation/controllers/current_user_provider.dart';
import 'package:paypaw/features/profile/domain/entities/user_profile.dart';
import 'package:paypaw/features/profile/presentation/controllers/profile_providers.dart';
import 'package:paypaw/features/profile/presentation/widgets/profile_avatar.dart';

import 'helpers/fake_avatar_store.dart';
import 'helpers/fake_profile_repository.dart';

/// The profile picture.
///
/// The interesting parts are not the circle: they are the **order** two stores
/// are written in, and the fact that a picture which cannot be shown falls back
/// to a letter rather than to a broken-image glyph.
void main() {
  late FakeProfileRepository repository;
  late FakeAvatarStore store;
  late ProviderContainer container;

  /// A container with the session and the profile already settled.
  ///
  /// Both awaits matter. `currentUserProvider` is a stream, so on the first
  /// synchronous read it has not emitted — `userProfileProvider` sees no session
  /// and completes with null, which is not the state any test here is about.
  Future<ProviderContainer> containerWith({UserProfile? profile}) async {
    repository = FakeProfileRepository(profile: profile);
    store = FakeAvatarStore();

    final ProviderContainer created = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
        avatarStoreProvider.overrideWithValue(store),
        currentUserProvider.overrideWith(
          (Ref ref) => Stream<AuthenticatedUser?>.value(
            const AuthenticatedUser(
              id: 'user-1',
              email: 'marc@example.com',
              hasConfirmedEmail: true,
            ),
          ),
        ),
      ],
    );
    addTearDown(created.dispose);

    // Listened to, not just read. Providers here auto-dispose, and one nothing
    // is subscribed to is torn down before its stream ever emits — the future
    // then never completes and the test times out rather than failing.
    created.listen(currentUserProvider, (_, _) {});
    created.listen(userProfileProvider, (_, _) {});
    created.listen(avatarUrlProvider, (_, _) {});

    await created.read(currentUserProvider.future);
    await created.read(userProfileProvider.future);

    return created;
  }

  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

  group('uploading', () {
    test('puts the object first and the row second', () async {
      // The other order would leave a row pointing at a picture that does not
      // exist, which reads as a broken avatar rather than as no avatar — and
      // there is nothing the user could do about it.
      container = await containerWith();
      final bool saved = await container
          .read(profileControllerProvider.notifier)
          .saveAvatar(bytes: bytes, contentType: 'image/jpeg');

      expect(saved, isTrue);
      expect(store.uploads, <(String, int)>[('image/jpeg', 4)]);
      expect(repository.savedAvatarPaths, <String?>['user-1/avatar']);
    });

    test('and writes no row at all when the upload fails', () async {
      container = await containerWith();
      store.failUpload = const NetworkException();

      final bool saved = await container
          .read(profileControllerProvider.notifier)
          .saveAvatar(bytes: bytes, contentType: 'image/jpeg');

      expect(saved, isFalse);
      expect(repository.savedAvatarPaths, isEmpty);
      expect(
        container.read(profileControllerProvider).errorMessage,
        'No internet connection. Check your network and try again.',
      );
    });
  });

  group('removing', () {
    test('clears the row first, then deletes the object', () async {
      // If the delete fails the row already says there is no picture, which is
      // the state the user asked for. The leftover object is invisible and the
      // next upload overwrites it.
      container = await containerWith(
        profile: const UserProfile(id: 'user-1', avatarUrl: 'user-1/avatar'),
      );
      final bool removed = await container
          .read(profileControllerProvider.notifier)
          .removeAvatar();

      expect(removed, isTrue);
      expect(repository.savedAvatarPaths, <String?>[null]);
      expect(store.removed, <String>['user-1/avatar']);
    });

    test('and touches no object when there was no picture', () async {
      container = await containerWith();
      await container.read(profileControllerProvider.notifier).removeAvatar();

      expect(store.removed, isEmpty);
    });
  });

  group('the URL', () {
    test('is null when there is no picture, so nothing is fetched', () async {
      container = await containerWith();

      expect(await container.read(avatarUrlProvider.future), isNull);
    });

    test('is signed, because the bucket is private', () async {
      container = await containerWith(
        profile: const UserProfile(id: 'user-1', avatarUrl: 'user-1/avatar'),
      );

      expect(
        await container.read(avatarUrlProvider.future),
        'https://example.test/user-1/avatar?token=abc',
      );
    });

    test('and null when one cannot be made', () async {
      // The object is gone, or the bucket does not exist because migration 0018
      // has not been applied. Either way the avatar shows a letter.
      container = await containerWith(
        profile: const UserProfile(id: 'user-1', avatarUrl: 'user-1/avatar'),
      );
      store.signedUrlIsNull = true;
      container.invalidate(avatarUrlProvider);

      expect(await container.read(avatarUrlProvider.future), isNull);
    });
  });

  group('what the circle shows', () {
    Future<void> pumpAvatar(
      WidgetTester tester, {
      UserProfile? profile,
      bool urlFails = false,
    }) async {
      repository = FakeProfileRepository(profile: profile);
      store = FakeAvatarStore(signedUrlIsNull: urlFails);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(repository),
            avatarStoreProvider.overrideWithValue(store),
            currentUserProvider.overrideWith(
              (Ref ref) => Stream<AuthenticatedUser?>.value(
                const AuthenticatedUser(
                  id: 'user-1',
                  email: 'marc@example.com',
                  hasConfirmedEmail: true,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: Center(child: ProfileAvatar(size: 64))),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the name is initial when there is no picture', (
      WidgetTester tester,
    ) async {
      await pumpAvatar(
        tester,
        profile: const UserProfile(id: 'user-1', displayName: 'Marc'),
      );

      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('and the address initial when there is no name either', (
      WidgetTester tester,
    ) async {
      await pumpAvatar(tester);

      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('a letter rather than a broken image when the URL fails', (
      WidgetTester tester,
    ) async {
      // A signed URL can expire mid-session and the object can be gone. Neither
      // is something the reader can act on, so neither is worth reporting.
      await pumpAvatar(
        tester,
        profile: const UserProfile(
          id: 'user-1',
          displayName: 'Marc',
          avatarUrl: 'user-1/avatar',
        ),
        urlFails: true,
      );

      expect(find.text('M'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('and no camera badge where it is not tappable', (
      WidgetTester tester,
    ) async {
      // The badge advertises a tap. On the dashboard header it is a control; if
      // ever drawn as decoration it should not claim to be one.
      await pumpAvatar(tester);

      expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);
    });
  });

  testWidgets('a tappable avatar says what it would do', (
    WidgetTester tester,
  ) async {
    repository = FakeProfileRepository();
    store = FakeAvatarStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repository),
          avatarStoreProvider.overrideWithValue(store),
          currentUserProvider.overrideWith(
            (Ref ref) => Stream<AuthenticatedUser?>.value(
              const AuthenticatedUser(
                id: 'user-1',
                email: 'marc@example.com',
                hasConfirmedEmail: true,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: ProfileAvatar(size: 64, showEditBadge: true, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Add a profile picture'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
  });
}
