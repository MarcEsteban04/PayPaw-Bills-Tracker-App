import '../entities/subscription_details.dart';

/// Rules for a subscription the user is entering.
///
/// Pure functions returning `null` when acceptable and a message otherwise —
/// Flutter's `FormFieldValidator` signature, the same shape as `BillValidators`.
/// Only the fields a bill does not have are here; the name, amount and schedule
/// are a recurring bill's and are validated as one.
abstract final class SubscriptionValidators {
  /// Matches the column checks, through the entity that owns them.
  static const int maxNameLength = SubscriptionDetails.nameMaxLength;

  /// Long enough for the deep links providers actually publish, short enough
  /// that a pasted essay is caught as the mistake it is.
  static const int maxUrlLength = 500;

  /// How far out a trial end date may sit.
  ///
  /// A trial is weeks, not years. Two years is generous for an annual plan's
  /// introductory period and still catches a mistyped year, which is the actual
  /// failure this rejects — `2062` for `2026`.
  static const int maxTrialYears = 2;

  /// A URI scheme at the front of what was typed, per RFC 3986.
  static final RegExp _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:');

  static String? provider(String? value) {
    final String trimmed = value?.trim() ?? '';

    if (trimmed.isEmpty) {
      return 'Say who charges for this';
    }
    if (trimmed.length > maxNameLength) {
      return 'Keep this under $maxNameLength characters';
    }

    return null;
  }

  static String? planName(String? value) {
    if ((value?.trim().length ?? 0) > maxNameLength) {
      return 'Keep this under $maxNameLength characters';
    }

    return null;
  }

  /// An optional label for the subscription inside PayPaw.
  ///
  /// Blank is fine and common — the form falls back to the provider — so this
  /// only guards the length.
  static String? name(String? value) {
    if ((value?.trim().length ?? 0) > maxNameLength) {
      return 'Keep this under $maxNameLength characters';
    }

    return null;
  }

  /// Checks a cancellation link, leniently.
  ///
  /// People paste `netflix.com/cancelplan` as often as they paste a full URL, and
  /// refusing that would be pedantry about a field whose only job is to be
  /// findable again later. [normalizeUrl] supplies the missing scheme; this only
  /// rejects what could never be a link at all.
  static String? cancellationUrl(String? value) {
    final String trimmed = value?.trim() ?? '';

    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length > maxUrlLength) {
      return 'That link is too long to store';
    }
    if (normalizeUrl(trimmed) == null) {
      return 'Enter a web address like netflix.com/cancelplan';
    }

    return null;
  }

  /// The link as it should be stored, or null when it is not one.
  ///
  /// Adds `https://` when no scheme was typed, because a stored `netflix.com`
  /// opens as a relative path in every browser and in `url_launcher`. Requires a
  /// dotted host, which is what separates a URL from a sentence.
  static String? normalizeUrl(String? value) {
    final String trimmed = value?.trim() ?? '';

    if (trimmed.isEmpty) {
      return null;
    }

    // Anything already carrying a scheme keeps it, and is then checked below.
    // Without this, `mailto:me@example.com` becomes `https://mailto:me@...`,
    // which parses cleanly as a host with a username and would be stored as a
    // link that goes nowhere.
    final bool hasScheme = _scheme.hasMatch(trimmed);
    final String withScheme = hasScheme ? trimmed : 'https://$trimmed';

    final Uri? parsed = Uri.tryParse(withScheme);

    if (parsed == null ||
        !<String>['http', 'https'].contains(parsed.scheme) ||
        !parsed.host.contains('.') ||
        parsed.host.endsWith('.')) {
      return null;
    }

    return withScheme;
  }

  /// Checks a trial end date. Null is acceptable — most subscriptions have no
  /// trial, and one that did may have been recorded after it ended.
  ///
  /// [today] is passed in rather than read from the clock, so this stays a pure
  /// function and a test does not have to mock time.
  static String? trialEndsOn(DateTime? value, {required DateTime today}) {
    if (value == null) {
      return null;
    }

    if (value.isAfter(
      DateTime(today.year + maxTrialYears, today.month, today.day),
    )) {
      return 'That is more than $maxTrialYears years away — check the year';
    }

    return null;
  }
}
