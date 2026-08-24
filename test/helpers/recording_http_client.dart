import 'dart:convert';

import 'package:http/http.dart' as http;

/// One request the client was asked to send.
class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String body;

  /// The path after `/rest/v1/` — the table or view being addressed.
  String get target => url.pathSegments.last;

  /// PostgREST puts filters, the select list and ordering in the query string,
  /// so this is where most assertions look.
  Map<String, String> get query => url.queryParameters;

  /// The decoded JSON body, for inserts and updates.
  Map<String, dynamic> get json => jsonDecode(body) as Map<String, dynamic>;

  @override
  String toString() => '$method $url${body.isEmpty ? '' : ' $body'}';
}

/// An `http.Client` that records what it was asked to send and replies with
/// canned JSON.
///
/// This is what makes [SupabaseBillRepository] testable at all. Everything
/// interesting about a repository over PostgREST lives in the request it builds —
/// which columns it selects, which filters it applies, what order it asks for,
/// what it puts in the body and, crucially, what it *leaves out*. None of that is
/// reachable by testing pure functions, and all of it fails at runtime rather
/// than at compile time.
///
/// Deliberately not a mock of `SupabaseClient`: mocking the SDK would test that
/// the code calls the methods the test expects, which is a restatement of the
/// implementation. Recording the HTTP layer tests what the *database* would
/// receive, which is the thing that has to be right.
class RecordingHttpClient extends http.BaseClient {
  RecordingHttpClient({this.respondWith = '[]', this.statusCode = 200});

  /// The body every request gets back. Set per test.
  String respondWith;

  int statusCode;

  final List<RecordedRequest> requests = <RecordedRequest>[];

  /// The only request sent. Fails the read if there was not exactly one, which is
  /// itself worth catching — a repository method making two round trips where one
  /// was intended is a bug the tests should notice.
  RecordedRequest get single {
    if (requests.length != 1) {
      throw StateError(
        'Expected exactly one request, got ${requests.length}: $requests',
      );
    }
    return requests.single;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final String body = request is http.Request ? request.body : '';

    requests.add(
      RecordedRequest(
        method: request.method,
        url: request.url,
        headers: Map<String, String>.of(request.headers),
        body: body,
      ),
    );

    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(respondWith)),
      statusCode,
      request: request,
      headers: <String, String>{'content-type': 'application/json'},
    );
  }
}
