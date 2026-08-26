import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/subscriptions/data/dtos/subscription_details_dto.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription_details.dart';

/// The mapper between `public.subscriptions` and the entity.
///
/// Hand-written, so every column name here is a string the compiler will never
/// check against `0006_subscriptions.sql`. A typo is a runtime failure on a
/// device, and this is the only place it can be caught.
void main() {
  group('toEntity', () {
    test('names the columns the migration declares', () {
      final SubscriptionDetails details = SubscriptionDetailsDto.toEntity(
        <String, dynamic>{
          'recurring_bill_id': 'sub-1',
          'provider': 'Netflix',
          'plan_name': 'Premium',
          'trial_ends_on': '2026-09-10',
          'auto_renews': false,
          'cancellation_url': 'https://netflix.com/cancel',
        },
      );

      expect(details.recurringBillId, 'sub-1');
      expect(details.provider, 'Netflix');
      expect(details.planName, 'Premium');
      expect(details.trialEndsOn, DateTime(2026, 9, 10));
      expect(details.autoRenews, isFalse);
      expect(details.cancellationUrl, 'https://netflix.com/cancel');
    });

    test('a blank optional is no value', () {
      final SubscriptionDetails details = SubscriptionDetailsDto.toEntity(
        <String, dynamic>{
          'recurring_bill_id': 'sub-1',
          'provider': 'Netflix',
          'plan_name': '  ',
          'cancellation_url': '',
        },
      );

      expect(details.planName, isNull);
      expect(details.cancellationUrl, isNull);
    });

    test('a missing auto_renews reads as renewing', () {
      // The column is `not null default true`, so null means a row written
      // before it existed. Renewing is the assumption that costs least: being
      // warned about one that had already stopped is a smaller failure than not
      // being warned about one that had not.
      expect(
        SubscriptionDetailsDto.toEntity(<String, dynamic>{
          'recurring_bill_id': 'sub-1',
          'provider': 'Netflix',
        }).autoRenews,
        isTrue,
      );
    });

    test('and an unreadable trial date costs the trial, not the row', () {
      final SubscriptionDetails details = SubscriptionDetailsDto.toEntity(
        <String, dynamic>{
          'recurring_bill_id': 'sub-1',
          'provider': 'Netflix',
          'trial_ends_on': 'next Tuesday',
        },
      );

      expect(details.trialEndsOn, isNull);
      // A row that would not map at all is a subscription the user cannot see
      // or cancel, which is far worse than a missing warning.
      expect(details.provider, 'Netflix');
    });
  });

  group('toUpsert', () {
    SubscriptionDetails details({
      String? planName,
      DateTime? trialEndsOn,
      String? cancellationUrl,
    }) => SubscriptionDetails(
      recurringBillId: 'sub-1',
      provider: 'Netflix',
      planName: planName,
      trialEndsOn: trialEndsOn,
      cancellationUrl: cancellationUrl,
    );

    test('carries the owner, which the policy compares against', () {
      // `user_id` is denormalised onto this table so RLS is a column comparison
      // rather than a join — so an inserted row cannot be attributed without it.
      expect(
        SubscriptionDetailsDto.toUpsert(details(), userId: 'user-9')['user_id'],
        'user-9',
      );
    });

    test('sends nulls rather than omitting them', () {
      // A trial date or a cancellation link cleared back to nothing has to
      // overwrite what was stored; a map without the key leaves it in place.
      final Map<String, dynamic> values = SubscriptionDetailsDto.toUpsert(
        details(),
        userId: 'user-1',
      );

      expect(values.keys, contains('plan_name'));
      expect(values.keys, contains('trial_ends_on'));
      expect(values.keys, contains('cancellation_url'));
      expect(values['plan_name'], isNull);
      expect(values['trial_ends_on'], isNull);
      expect(values['cancellation_url'], isNull);
    });

    test('a date goes as a date, not a timestamp', () {
      // The column is `date`. A timestamp would be truncated by Postgres in
      // whatever zone it felt like, which is how a trial ends a day early.
      expect(
        SubscriptionDetailsDto.toUpsert(
          details(trialEndsOn: DateTime(2026, 9, 10, 23, 59)),
          userId: 'user-1',
        )['trial_ends_on'],
        '2026-09-10',
      );
    });

    test('and pads a single-digit month and day', () {
      expect(
        SubscriptionDetailsDto.toUpsert(
          details(trialEndsOn: DateTime(2026, 1, 5)),
          userId: 'user-1',
        )['trial_ends_on'],
        '2026-01-05',
      );
    });

    test('the provider is trimmed', () {
      expect(
        SubscriptionDetailsDto.toUpsert(
          const SubscriptionDetails(
            recurringBillId: 'sub-1',
            provider: '  Netflix  ',
          ),
          userId: 'user-1',
        )['provider'],
        'Netflix',
      );
    });

    test('a round trip through the wire keeps every field', () {
      const SubscriptionDetails original = SubscriptionDetails(
        recurringBillId: 'sub-1',
        provider: 'Netflix',
        planName: 'Premium',
        autoRenews: false,
        cancellationUrl: 'https://netflix.com/cancel',
      );

      expect(
        SubscriptionDetailsDto.toEntity(
          SubscriptionDetailsDto.toUpsert(original, userId: 'user-1'),
        ),
        original,
      );
    });
  });
}
