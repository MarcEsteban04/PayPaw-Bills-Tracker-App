import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/payments/data/repositories/supabase_payment_repository.dart';
import 'package:paypaw/features/payments/domain/entities/new_payment.dart';
import 'package:paypaw/features/payments/domain/entities/payment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/recording_http_client.dart';

/// The repository, tested against the request it actually sends.
///
/// A repository over PostgREST is almost entirely request-building: which columns
/// it selects, which filters it applies, and what order it asks for. None of that
/// is reachable by testing pure functions, and all of it fails at runtime rather
/// than at compile time — so it is tested at the HTTP layer, where the assertions
/// are about what the *database* would receive.
void main() {
  late RecordingHttpClient http;
  late SupabaseClient client;
  late SupabasePaymentRepository repository;

  setUp(() {
    http = RecordingHttpClient();
    client = SupabaseClient(
      'https://project.supabase.co',
      'sb_publishable_test',
      httpClient: http,
    );
    repository = SupabasePaymentRepository(client);
  });

  tearDown(() => client.dispose());

  Map<String, dynamic> row({
    String id = 'pay-1',
    int amountMinor = 60000,
    String paidAt = '2026-08-14T09:30:00Z',
  }) => <String, dynamic>{
    'id': id,
    'user_id': 'user-1',
    'bill_id': 'bill-1',
    'debt_id': null,
    'amount_minor': amountMinor,
    'currency': 'PHP',
    'paid_at': paidAt,
    'method': 'gcash',
    'reference': null,
    'note': null,
    'created_at': paidAt,
    'updated_at': paidAt,
  };

  group('fetchPaymentsForBill', () {
    test('asks for one bill\'s payments, most recent first', () async {
      http.respondWith = jsonEncode(<Map<String, dynamic>>[row()]);

      await repository.fetchPaymentsForBill('bill-1');

      final Uri url = http.single.url;
      expect(url.path, endsWith('/rest/v1/payments'));
      expect(url.queryParameters['bill_id'], 'eq.bill-1');
      // Descending. The question a history answers is "did the last one go
      // through", not "how did this start".
      expect(url.queryParameters['order'], contains('paid_at.desc'));
    });

    test('names its columns instead of selecting everything', () async {
      // `select('*')` would mean adding a column to the table silently changes
      // what the app fetches.
      http.respondWith = jsonEncode(<Map<String, dynamic>>[row()]);

      await repository.fetchPaymentsForBill('bill-1');

      final String? select = http.single.url.queryParameters['select'];
      expect(select, isNot('*'));
      expect(select, contains('amount_minor'));
      expect(select, contains('paid_at'));
    });

    test('never filters on user_id', () async {
      // The RLS policy already restricts every row to user_id = auth.uid().
      // Repeating it in the query would express the same constraint somewhere it
      // can drift from the policy, and would read as though the query were doing
      // the securing. The policy secures this.
      http.respondWith = jsonEncode(<Map<String, dynamic>>[row()]);

      await repository.fetchPaymentsForBill('bill-1');

      expect(http.single.url.queryParameters.containsKey('user_id'), isFalse);
    });

    test('maps the rows', () async {
      http.respondWith = jsonEncode(<Map<String, dynamic>>[
        row(amountMinor: 40000),
      ]);

      final List<Payment> payments = await repository.fetchPaymentsForBill(
        'bill-1',
      );

      expect(payments, hasLength(1));
      expect(payments.single.amount.format(), '₱400.00');
    });

    test('a bill with no payments is an empty list, not an error', () async {
      // Also the answer for a bill that does not exist or belongs to someone
      // else. Those are the same answer through RLS and have to stay the same
      // answer — reporting them differently would confirm a stranger's bill
      // exists.
      http.respondWith = '[]';

      expect(await repository.fetchPaymentsForBill('bill-1'), isEmpty);
    });

    test(
      'an unreadable row becomes an AppException, not a FormatException',
      () async {
        // Nothing above the repository knows how to show a parser error.
        http.respondWith = jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{'id': 'pay-1'},
        ]);

        await expectLater(
          repository.fetchPaymentsForBill('bill-1'),
          throwsA(isA<ServerException>()),
        );
      },
    );

    test('a server error becomes an AppException too', () async {
      http
        ..statusCode = 500
        ..respondWith = jsonEncode(<String, dynamic>{'message': 'boom'});

      await expectLater(
        repository.fetchPaymentsForBill('bill-1'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('recordPayment', () {
    test('refuses without a session, and sends nothing', () async {
      // `user_id` is not a parameter anywhere in this repository — it comes from
      // the session, and the RLS policy checks it on the way in. Without one
      // there is no row to write, and firing the request anyway would trade a
      // clear message for a 401 the UI has to guess at.
      await expectLater(
        repository.recordPayment(
          NewPayment.forBill(
            billId: 'bill-1',
            amount: const Money.php(50000),
            paidAt: DateTime.utc(2026, 8, 25),
          ),
        ),
        throwsA(isA<AuthenticationException>()),
      );

      expect(http.requests, isEmpty);
    });
  });
}
