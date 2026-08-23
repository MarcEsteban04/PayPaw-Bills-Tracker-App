/// Whether a password satisfies each individual rule.
///
/// A record rather than a class: it is three booleans with no behaviour, and the
/// UI wants them separately so it can show which rule is not met yet.
typedef PasswordRequirements = ({
  bool hasMinLength,
  bool hasLetter,
  bool hasNumber,
});

/// Credential rules, as pure functions.
///
/// Pure Dart in the domain layer, so the same rules serve registration, login
/// and password recovery without three copies drifting apart — and so they can be
/// tested without pumping a widget.
///
/// Each function returns `null` when the value is acceptable and a message when
/// it is not, which is exactly Flutter's `FormFieldValidator` signature. That
/// means a `TextFormField` can take one directly.
abstract final class AuthValidators {
  /// Shortest password PayPaw accepts.
  ///
  /// Eight rather than Supabase's default of six. Six-character passwords are
  /// trivially brute-forced offline if a database is ever leaked, and this is an
  /// app holding a picture of someone's finances.
  static const int minPasswordLength = 8;

  /// Deliberately permissive: one `@`, something before it, and a dotted domain
  /// after it.
  ///
  /// No attempt is made to implement RFC 5322 — full email grammar allows
  /// quoted strings, comments and IP literals, and every "strict" regex on the
  /// internet rejects addresses that genuinely work. The only real validation of
  /// an email address is whether the confirmation message arrives, and PayPaw
  /// requires confirmation anyway. This check exists to catch typos, not to
  /// adjudicate.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static final RegExp _letter = RegExp('[A-Za-z]');
  static final RegExp _digit = RegExp('[0-9]');

  /// Validates an email address.
  static String? email(String? value) {
    final String trimmed = value?.trim() ?? '';

    if (trimmed.isEmpty) {
      return 'Enter your email address';
    }
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'That does not look like an email address';
    }

    return null;
  }

  /// Validates a new password.
  ///
  /// Not trimmed: a leading or trailing space is a legitimate password
  /// character, and silently stripping it would lock the user out of the account
  /// they just created.
  static String? password(String? value) {
    final String password = value ?? '';

    if (password.isEmpty) {
      return 'Choose a password';
    }

    final PasswordRequirements met = requirements(password);

    if (!met.hasMinLength) {
      return 'Use at least $minPasswordLength characters';
    }
    if (!met.hasLetter) {
      return 'Include at least one letter';
    }
    if (!met.hasNumber) {
      return 'Include at least one number';
    }

    return null;
  }

  /// Validates the second password field against the first.
  static String? passwordConfirmation(String? value, String password) {
    if ((value ?? '').isEmpty) {
      return 'Re-enter your password';
    }
    if (value != password) {
      return 'Those passwords do not match';
    }

    return null;
  }

  /// Which rules [password] currently satisfies, for a live checklist.
  static PasswordRequirements requirements(String password) => (
    hasMinLength: password.length >= minPasswordLength,
    hasLetter: _letter.hasMatch(password),
    hasNumber: _digit.hasMatch(password),
  );
}
