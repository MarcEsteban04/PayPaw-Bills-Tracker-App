import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/bills/data/repositories/supabase_bill_repository.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/domain/entities/new_bill.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/recording_http_client.dart';

/// The repository, tested against the requests it actually sends.
///
/// A repository over PostgREST is almost entirely request-building: which columns
/// it selects, which filters it applies, what order it asks for, and what it
/// leaves out of a body. None of that is reachable by testing pure functions, and
/// every part of it fails at runtime rather than at compile time — so it is tested
/// at the HTTP layer, where the assertions are about what the *database* would
/// receive.
void main() {
  const String userId = 'user-1';

  late RecordingHttpClient http;
  late SupabaseClient client;
  late SupabaseBillRepository repository;

  /// A session the client accepts without a network call.
  ///
  /// `recoverSession` saves a session locally as long as it has not expired, so a
  /// far-future expiry gives the repository a `currentUser` with no server
  /// involved.
  String sessionJson() => jsonEncode(<String, dynamic>{
    'access_token': 'test-access-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at':
        DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/
        1000,
    'refresh_token': 'test-refresh-token',
    'user': <String, dynamic>{
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'marc@example.com',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    },
  });

  Future<void> signIn() => client.auth.recoverSession(sessionJson());

  setUp(() {
    http = RecordingHttpClient();
    client = SupabaseClient(
      'https://project.supabase.co',
      'sb_publishable_test',
      httpClient: http,
    );
    repository = SupabaseBillRepository(client);
  });

  tearDown(() => client.dispose());

  /// A `bill_status` row, shaped as PostgREST returns one.
  Map<String, dynamic> viewRow({
    String id = 'bill-1',
    String name = 'Meralco electricity',
    String status = 'due_soon',
    Object? paidMinor = 0,
    Object? outstandingMinor = 245050,
    Object? archivedAt,
    Object? lastPaidAt,
  }) => <String, dynamic>{
    'bill_id': id,
    'user_id': userId,
    'category_id': null,
    'recurring_bill_id': null,
    'name': name,
    'payee': 'Meralco',
    'amount_minor': 245050,
    'currency': 'PHP',
    'due_on': '2026-09-05',
    'notes': null,
    'archived_at': archivedAt,
    'created_at': '2026-08-24T02:15:00Z',
    'updated_at': '2026-08-24T02:15:00Z',
    'status': status,
    'paid_minor': paidMinor,
    'outstanding_minor': outstandingMinor,
    'last_paid_at': lastPaidAt,
    'today': '2026-09-03',
  };

  /// A `bills` row, as a write returns one.
  Map<String, dynamic> tableRow({Object? archivedAt}) => <String, dynamic>{
    'id': 'bill-1',
    'user_id': userId,
    'category_id': null,
    'recurring_bill_id': null,
    'name': 'Meralco electricity',
    'payee': 'Meralco',
    'amount_minor': 245050,
    'currency': 'PHP',
    'due_on': '2026-09-05',
    'notes': null,
    'archived_at': archivedAt,
    'created_at': '2026-08-24T02:15:00Z',
    'updated_at': '2026-08-24T02:15:00Z',
  };

  final Bill bill = Bill(
    id: 'bill-1',
    userId: userId,
    name: 'Meralco electricity',
    payee: 'Meralco',
    amount: const Money.php(245050),
    dueOn: DateTime(2026, 9, 5),
    createdAt: DateTime(2026, 8, 24),
    updatedAt: DateTime(2026, 8, 24),
  );

  group('fetchBills', () {
    test('reads the view, not the table', () async {
      // The whole reason 0014 exists: the view carries the derived status and the
      // payment totals, so a list is one round trip. Reading `bills` here would
      // mean a second query and a client-side join.
      http.respondWith = jsonEncode(<Map<String, dynamic>>[viewRow()]);

      await repository.fetchBills();

      expect(http.single.target, 'bill_status');
      expect(http.single.method, 'GET');
    });

    test('names every column it reads, rather than selecting star', () async {
      http.respondWith = jsonEncode(<Map<String, dynamic>>[viewRow()]);

      await repository.fetchBills();

      final String select = http.single.query['select']!;

      expect(select, isNot(contains('*')));
      for (final String column in <String>[
        'bill_id',
        'name',
        'amount_minor',
        'currency',
        'due_on',
        'archived_at',
        'paid_minor',
        'outstanding_minor',
        'last_paid_at',
        'today',
        'status',
      ]) {
        expect(select, contains(column), reason: '$column is not selected');
      }
    });

    test('hides archived bills by default', () async {
      // Archiving is the user saying "stop showing me this". A list that ignores
      // it ignores them.
      http.respondWith = jsonEncode(<Map<String, dynamic>>[viewRow()]);

      await repository.fetchBills();

      expect(http.single.query['archived_at'], 'is.null');
    });

    test('includes them when asked', () async {
      http.respondWith = jsonEncode(<Map<String, dynamic>>[viewRow()]);

      await repository.fetchBills(includeArchived: true);

      expect(http.single.query.containsKey('archived_at'), isFalse);
    });

    test('orders by due date, then by name', () async {
      // Soonest first, because "what is next" is the question the list exists to
      // answer. The name is a tie-break: without it two bills due the same day
      // come back in whatever order Postgres chose, which reads as the list
      // shuffling itself between refreshes.
      http.respondWith = jsonEncode(<Map<String, dynamic>>[viewRow()]);

      await repository.fetchBills();

      // Spelled out rather than matched loosely: the direction is the whole
      // point, and postgrest-dart's `order` defaults to descending. The first
      // run of this test found exactly that — the list was sorted latest-due
      // first, with the overdue bills at the bottom.
      expect(
        http.single.query['order'],
        'due_on.asc.nullslast,name.asc.nullslast',
      );
    });

    test('maps rows into entities', () async {
      http.respondWith = jsonEncode(<Map<String, dynamic>>[
        viewRow(),
        viewRow(id: 'bill-2', name: 'Globe fibre', status: 'paid'),
      ]);

      final List<BillWithStatus> bills = await repository.fetchBills();

      expect(bills, hasLength(2));
      expect(bills.first.bill.name, 'Meralco electricity');
      expect(bills.first.status, BillStatus.dueSoon);
      expect(bills.first.outstanding, const Money.php(245050));
      expect(bills.last.status, BillStatus.paid);
    });

    test('an empty table is an empty list, not an error', () async {
      http.respondWith = '[]';

      expect(await repository.fetchBills(), isEmpty);
    });

    test('needs no session of its own', () async {
      // RLS decides what comes back. The repository does not filter on user_id,
      // and it does not need to know who is asking to build the query.
      http.respondWith = '[]';

      await expectLater(repository.fetchBills(), completes);
    });
  });

  group('fetchBill', () {
    test('filters by the view key, which is bill_id and not id', () async {
      // The view joins three tables, so the bill's key is renamed. Getting this
      // wrong is a 400 from PostgREST at runtime, on a detail screen.
      http.respondWith = jsonEncode(viewRow());

      await repository.fetchBill('bill-1');

      expect(http.single.query['bill_id'], 'eq.bill-1');
    });

    test('returns null for a bill that is not there', () async {
      // Also the answer for somebody else's bill. Under RLS the two are the same
      // case and have to stay the same case: distinguishing them would confirm
      // that a stranger's bill exists.
      http.respondWith = 'null';

      expect(await repository.fetchBill('missing'), isNull);
    });

    test('maps the row when it is there', () async {
      http.respondWith = jsonEncode(
        viewRow(paidMinor: 100000, outstandingMinor: 145050),
      );

      final BillWithStatus? found = await repository.fetchBill('bill-1');

      expect(found, isNotNull);
      expect(found!.paid, const Money.php(100000));
      expect(found.outstanding, const Money.php(145050));
      expect(found.isPartiallyPaid, isTrue);
    });
  });

  group('createBill', () {
    final NewBill draft = NewBill(
      name: 'Maynilad water',
      amount: const Money.php(89000),
      dueOn: DateTime(2026, 10, 12),
    );

    test('writes to the table, not the view', () async {
      await signIn();
      http.respondWith = jsonEncode(tableRow());

      await repository.createBill(draft);

      expect(http.single.target, 'bills');
      expect(http.single.method, 'POST');
    });

    test('sends the owner from the session', () async {
      // A NewBill has no userId, so this is the only place it can come from — and
      // a caller cannot supply somebody else's.
      await signIn();
      http.respondWith = jsonEncode(tableRow());

      await repository.createBill(draft);

      expect(http.single.json['user_id'], userId);
    });

    test(
      'sends the amount in minor units and the date as a bare date',
      () async {
        await signIn();
        http.respondWith = jsonEncode(tableRow());

        await repository.createBill(draft);

        expect(http.single.json['amount_minor'], 89000);
        expect(http.single.json['due_on'], '2026-10-12');
      },
    );

    test('asks for the stored row back', () async {
      // So the caller learns the id the database assigned without a second round
      // trip.
      await signIn();
      http.respondWith = jsonEncode(tableRow());

      final Bill created = await repository.createBill(draft);

      expect(http.single.query.containsKey('select'), isTrue);
      expect(created.id, 'bill-1');
    });

    test('refuses without a session, before sending anything', () async {
      // The insert needs a user_id and there is nowhere to get one. Sending it
      // anonymously would fail at the NOT NULL constraint with a message about
      // columns.
      await expectLater(
        repository.createBill(draft),
        throwsA(isA<AuthenticationException>()),
      );

      expect(http.requests, isEmpty);
    });
  });

  group('updateBill', () {
    test('patches the table by id', () async {
      await signIn();
      http.respondWith = jsonEncode(tableRow());

      await repository.updateBill(bill);

      expect(http.single.method, 'PATCH');
      expect(http.single.target, 'bills');
      expect(http.single.query['id'], 'eq.bill-1');
    });

    test('does not send user_id', () async {
      // Ownership is not editable. Sending it would be an update the RLS policy
      // has to reject rather than one it never sees.
      await signIn();
      http.respondWith = jsonEncode(tableRow());

      await repository.updateBill(bill);

      expect(http.single.json.containsKey('user_id'), isFalse);
    });

    test('does not filter on user_id either', () async {
      // The policy already restricts every statement to the caller's rows.
      // Repeating it here would state the same constraint twice, in a place that
      // can drift from the policy — and would read as though the query were doing
      // the securing.
      await signIn();
      http.respondWith = jsonEncode(tableRow());

      await repository.updateBill(bill);

      expect(http.single.query.containsKey('user_id'), isFalse);
    });
  });

  group('archiving', () {
    test('stamps archived_at and nothing else', () async {
      await signIn();
      http.respondWith = jsonEncode(
        tableRow(archivedAt: '2026-09-01T00:00:00Z'),
      );

      final Bill archived = await repository.archiveBill('bill-1');

      expect(http.single.json.keys, <String>['archived_at']);
      expect(http.single.json['archived_at'], isA<String>());
      expect(archived.isArchived, isTrue);
    });

    test('restoring clears it', () async {
      // Explicitly null, which is what tells PostgREST to write the column rather
      // than leave it alone.
      await signIn();
      http.respondWith = jsonEncode(tableRow());

      final Bill restored = await repository.unarchiveBill('bill-1');

      expect(http.single.json, <String, dynamic>{'archived_at': null});
      expect(restored.isArchived, isFalse);
    });
  });

  group('deleteBill', () {
    test('deletes by id', () async {
      http.respondWith = '[]';

      await repository.deleteBill('bill-1');

      expect(http.single.method, 'DELETE');
      expect(http.single.target, 'bills');
      expect(http.single.query['id'], 'eq.bill-1');
    });
  });

  group('errors', () {
    test('a PostgREST failure becomes an AppException', () async {
      // Nothing above the data layer knows what a PostgrestException is.
      http
        ..statusCode = 500
        ..respondWith = jsonEncode(<String, dynamic>{
          'message': 'boom',
          'code': 'XX000',
        });

      await expectLater(repository.fetchBills(), throwsA(isA<AppException>()));
    });

    test('a row the mapper cannot read becomes an AppException too', () async {
      // A raw FormatException escaping here would reach a UI that only knows how
      // to display an AppException.
      final Map<String, dynamic> broken = viewRow()..remove('amount_minor');
      http.respondWith = jsonEncode(<Map<String, dynamic>>[broken]);

      await expectLater(repository.fetchBills(), throwsA(isA<AppException>()));
    });

    test('and never leaks a FormatException', () async {
      final Map<String, dynamic> broken = viewRow()..remove('today');
      http.respondWith = jsonEncode(<Map<String, dynamic>>[broken]);

      await expectLater(
        repository.fetchBills(),
        throwsA(isNot(isA<FormatException>())),
      );
    });
  });
}
