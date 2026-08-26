import 'package:meta/meta.dart';

/// PayPaw's own row for the signed-in account.
///
/// Distinct from `AuthenticatedUser`, which is Supabase's — the id and the email
/// belong to `auth.users` and are not ours to write. Everything here is, and
/// `public.profiles` has held it since migration 0002 with nothing in the app
/// reading it.
///
/// ## Two of these fields are load-bearing
///
/// [timeZone] decides which day it is for this user. `bill_status` computes
/// "due today" against it and `generate_recurring_bills` measures its horizon by
/// it, so a wrong zone is wrong *dates*, not a wrong clock — a bill can read as
/// due tomorrow when it was due yesterday.
///
/// [currency] is the default every new bill is written in. Changing it does not
/// convert anything, which is why it is not offered as a setting: the amounts
/// already stored would keep their numbers and quietly change meaning.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.currency = 'PHP',
    this.locale = 'en_PH',
    this.timeZone = 'Asia/Manila',
  });

  /// The same id as the account. The profile *is* the user.
  final String id;

  /// What this person calls themselves, or null if they have never said.
  ///
  /// Null rather than a derived default. "marcdelacruzesteban" pulled out of an
  /// email address is not a name anybody chose, and storing it would make the
  /// difference between chosen and guessed impossible to see later.
  final String? displayName;

  /// Set in Sprint 57, when there is somewhere to upload a picture to.
  final String? avatarUrl;

  final String currency;
  final String locale;

  /// An IANA zone name, not an offset. An offset cannot survive DST or a flight.
  final String timeZone;

  /// Whether this person has told PayPaw their name.
  bool get hasName => displayName != null && displayName!.trim().isNotEmpty;

  /// The longest a name may be, matching the column's own check.
  static const int nameMaxLength = 80;

  /// The name to show, or null to fall back to the address.
  ///
  /// Trimmed, because a name that is entirely spaces is a name nobody typed and
  /// would render as a blank line where the heading should be.
  String? get name => hasName ? displayName!.trim() : null;

  /// The letter for an avatar, given the email to fall back on.
  ///
  /// Here rather than in the widget because two screens draw this avatar and
  /// they must not disagree about whose initial it is.
  static String initialFor({String? name, String? email}) {
    final String source = switch ((name?.trim(), email)) {
      (final String n?, _) when n.isNotEmpty => n,
      (_, final String e?) when e.isNotEmpty => e,
      _ => '?',
    };

    return source.substring(0, 1).toUpperCase();
  }

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    String? currency,
    String? locale,
    String? timeZone,
    bool clearDisplayName = false,
  }) => UserProfile(
    id: id,
    displayName: clearDisplayName ? null : (displayName ?? this.displayName),
    avatarUrl: avatarUrl ?? this.avatarUrl,
    currency: currency ?? this.currency,
    locale: locale ?? this.locale,
    timeZone: timeZone ?? this.timeZone,
  );

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.currency == currency &&
      other.locale == locale &&
      other.timeZone == timeZone;

  @override
  int get hashCode =>
      Object.hash(id, displayName, avatarUrl, currency, locale, timeZone);

  @override
  String toString() => 'UserProfile($id, name: $displayName, tz: $timeZone)';
}
