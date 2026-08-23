/// A signed-in (or newly registered) PayPaw account.
///
/// Named `AuthenticatedUser` rather than `AuthUser` on purpose: Supabase exports
/// a public `AuthUser` of its own, and a domain entity colliding with an SDK
/// type forces every data-layer file to hide one or prefix the other. Better to
/// pick a name that cannot clash.
///
/// Deliberately small. It carries what the app needs to decide what to show —
/// who this is, and whether they have confirmed their address — and nothing
/// else. Profile details belong to a profile entity when there is one.
class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.email,
    required this.hasConfirmedEmail,
  });

  /// Supabase's user id. The primary key every future table will scope rows by.
  final String id;

  final String email;

  /// Whether the confirmation email has been acted on.
  ///
  /// False right after registration when confirmation is required, which is not
  /// an error — it is the normal path, and the reason `SignUpOutcome` exists.
  final bool hasConfirmedEmail;

  @override
  bool operator ==(Object other) =>
      other is AuthenticatedUser &&
      other.id == id &&
      other.email == email &&
      other.hasConfirmedEmail == hasConfirmedEmail;

  @override
  int get hashCode => Object.hash(id, email, hasConfirmedEmail);

  @override
  String toString() =>
      'AuthenticatedUser(id: $id, email: $email, confirmed: $hasConfirmedEmail)';
}
