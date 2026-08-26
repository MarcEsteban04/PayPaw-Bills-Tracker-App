import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/profile/domain/entities/user_profile.dart';
import 'package:paypaw/features/profile/domain/repositories/profile_repository.dart';

/// An in-memory [ProfileRepository].
///
/// Holds what was written, because the only thing that matters about a settings
/// screen is whether the tap reached the database — and [failWith] covers the
/// other half, since a write the user asked for and is watching has to report
/// when it does not land.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({
    UserProfile? profile,
    this.failWith,
    this.missing = false,
  }) : profile = profile ?? const UserProfile(id: 'user-1');

  UserProfile profile;

  /// What every call throws, or null if they succeed.
  AppException? failWith;

  /// Whether the profile row is absent, which the trigger in migration 0002
  /// should make impossible and which the repository reports rather than
  /// papering over.
  bool missing;

  /// Every name written, in order. A cleared name appears as null.
  final List<String?> savedNames = <String?>[];

  /// Every zone written, in order.
  final List<String> savedZones = <String>[];

  /// Every avatar path written, in order. Removing one appears as null.
  final List<String?> savedAvatarPaths = <String?>[];

  @override
  Future<UserProfile> fetch() async {
    _failIfAsked();

    if (missing) {
      throw const NotFoundException(
        message: 'We could not find your profile. Try signing in again.',
      );
    }

    return profile;
  }

  @override
  Future<void> saveDisplayName(String? name) async {
    _failIfAsked();

    savedNames.add(name);
    profile = name == null
        ? profile.copyWith(clearDisplayName: true)
        : profile.copyWith(displayName: name);
  }

  @override
  Future<void> saveAvatarPath(String? path) async {
    _failIfAsked();

    savedAvatarPaths.add(path);
    profile = path == null
        ? UserProfile(
            id: profile.id,
            displayName: profile.displayName,
            currency: profile.currency,
            locale: profile.locale,
            timeZone: profile.timeZone,
          )
        : profile.copyWith(avatarUrl: path);
  }

  @override
  Future<void> saveTimeZone(String zone) async {
    _failIfAsked();

    savedZones.add(zone);
    profile = profile.copyWith(timeZone: zone);
  }

  void _failIfAsked() {
    if (failWith case final AppException exception) {
      throw exception;
    }
  }
}
