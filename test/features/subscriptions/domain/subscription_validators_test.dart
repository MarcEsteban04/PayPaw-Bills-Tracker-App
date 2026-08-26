import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/subscriptions/domain/validation/subscription_validators.dart';

/// The rules a subscription form enforces before the round trip.
///
/// The cancellation link is the one worth this much attention. It is stored so
/// it can be opened later, and a stored `netflix.com` opens as a *relative path*
/// in every browser — so the normalisation is not cosmetic, it is the difference
/// between a link that works and one that 404s months after anybody could
/// remember typing it.
void main() {
  group('provider', () {
    test('is required', () {
      expect(SubscriptionValidators.provider('  '), 'Say who charges for this');
    });

    test('accepts a name and rejects an essay', () {
      expect(SubscriptionValidators.provider('Netflix'), isNull);
      expect(
        SubscriptionValidators.provider(
          'x' * (SubscriptionValidators.maxNameLength + 1),
        ),
        isNotNull,
      );
    });
  });

  group('normalizeUrl', () {
    test('supplies the scheme people never type', () {
      expect(
        SubscriptionValidators.normalizeUrl('netflix.com/cancelplan'),
        'https://netflix.com/cancelplan',
      );
    });

    test('leaves a scheme that is already there', () {
      expect(
        SubscriptionValidators.normalizeUrl('http://example.com/x'),
        'http://example.com/x',
      );
      expect(
        SubscriptionValidators.normalizeUrl('https://example.com/x'),
        'https://example.com/x',
      );
    });

    test('is null for nothing, so a blank field clears the column', () {
      expect(SubscriptionValidators.normalizeUrl(null), isNull);
      expect(SubscriptionValidators.normalizeUrl('   '), isNull);
    });

    test('rejects what could never be a link', () {
      // A dotted host is what separates a URL from a sentence. Without this
      // check "cancel it online" normalises to `https://cancel it online`,
      // which parses and is nonsense.
      expect(SubscriptionValidators.normalizeUrl('cancel it online'), isNull);
      expect(SubscriptionValidators.normalizeUrl('netflix'), isNull);
      expect(SubscriptionValidators.normalizeUrl('netflix.'), isNull);
      // Schemes that are not the web. `mailto:` and `javascript:` are the two
      // that matter, for opposite reasons.
      expect(SubscriptionValidators.normalizeUrl('mailto:a@b.com'), isNull);
      expect(
        SubscriptionValidators.normalizeUrl('javascript://x.com/'),
        isNull,
      );
    });
  });

  group('cancellationUrl', () {
    test('is optional', () {
      expect(SubscriptionValidators.cancellationUrl(''), isNull);
      expect(SubscriptionValidators.cancellationUrl(null), isNull);
    });

    test('complains about anything normalisation cannot rescue', () {
      expect(SubscriptionValidators.cancellationUrl('netflix.com'), isNull);
      expect(
        SubscriptionValidators.cancellationUrl('somewhere in my email'),
        'Enter a web address like netflix.com/cancelplan',
      );
    });

    test('rejects a pasted essay by length', () {
      expect(
        SubscriptionValidators.cancellationUrl(
          'https://example.com/${'x' * SubscriptionValidators.maxUrlLength}',
        ),
        'That link is too long to store',
      );
    });
  });

  group('trialEndsOn', () {
    final DateTime today = DateTime(2026, 8, 27);

    test('is optional — most subscriptions never had a trial', () {
      expect(SubscriptionValidators.trialEndsOn(null, today: today), isNull);
    });

    test('accepts a trial that has already ended', () {
      // Recording a subscription after the fact is normal, and the trial end is
      // still worth keeping: it is why the price changed.
      expect(
        SubscriptionValidators.trialEndsOn(DateTime(2025, 3, 4), today: today),
        isNull,
      );
    });

    test('catches the mistyped year', () {
      expect(
        SubscriptionValidators.trialEndsOn(DateTime(2062, 9, 15), today: today),
        isNotNull,
      );
      expect(
        SubscriptionValidators.trialEndsOn(DateTime(2026, 9, 26), today: today),
        isNull,
      );
    });
  });
}
