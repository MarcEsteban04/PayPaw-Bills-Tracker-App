import '../entities/user_profile.dart';

/// Reads and writes the signed-in account's own row.
///
/// Ownership is never a parameter. The RLS policy restricts every statement to
/// `id = auth.uid()`, so there is exactly one profile this can return — and
/// passing an id would express the same constraint a second time, somewhere it
/// can drift from the policy.
abstract interface class ProfileRepository {
  /// The signed-in user's profile.
  ///
  /// **A missing row is an error here, unlike the reminder preferences.** A
  /// trigger creates the profile during sign-up, so its absence means something
  /// genuinely went wrong rather than "not set yet", and inventing a default
  /// would hide it.
  Future<UserProfile> fetch();

  /// Sets or clears the display name.
  ///
  /// Null, or anything that trims to nothing, clears it — which is a real
  /// choice: somebody who deletes their name is asking to be a nameless
  /// account again, not asking for the empty string.
  Future<void> saveDisplayName(String? name);

  /// Sets the zone the account's dates are computed in.
  ///
  /// An IANA name. This is not cosmetic: `bill_status` decides "due today"
  /// against it and `generate_recurring_bills` measures its horizon by it.
  Future<void> saveTimeZone(String zone);
}
