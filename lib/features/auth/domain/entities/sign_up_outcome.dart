import 'authenticated_user.dart';

/// What happened when an account was created.
///
/// Registration has two successful endings, and conflating them is a common bug:
/// with email confirmation enabled, Supabase creates the user but returns **no
/// session**, so the app is *not* signed in. Treating that as a normal sign-in
/// leaves the user on a dashboard that cannot load anything.
///
/// A sealed type forces the caller to handle both.
sealed class SignUpOutcome {
  const SignUpOutcome();
}

/// The account exists and a confirmation email is on its way. The user is not
/// signed in yet.
final class SignUpNeedsConfirmation extends SignUpOutcome {
  const SignUpNeedsConfirmation({required this.email});

  /// Where the confirmation was sent, so the UI can say so.
  final String email;
}

/// The account exists and the user is signed in — the case when email
/// confirmation is turned off in the Supabase project.
final class SignUpSignedIn extends SignUpOutcome {
  const SignUpSignedIn({required this.user});

  final AuthenticatedUser user;
}
