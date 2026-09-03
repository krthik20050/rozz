import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rozz/features/statement_upload/data/datasources/statement_sync_api.dart';
import 'package:rozz/features/statement_upload/domain/repositories/statement_sync_repository.dart';

void main() {
  const baseUrl = 'https://rozz.example.com';
  const apiKey = 'secret-key';

  test('fetchRows parses the server rows payload', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'rows': [
            {
              'fingerprint': 'abc123',
              'date': '2026-08-01',
              'amount': 189.0,
              'direction': 'debit',
              'label_type': 'upi',
              'balance_after': 3540.11,
              'ref': '123456789012',
              'vpa': 'swiggy@ybl',
              'payee': 'Swiggy',
              'narration': '[upi]-[ref]-for dinner',
              'category': 'Food',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = StatementSyncApi(client: client);
    final rows = await api.fetchRows(
      baseUrl: baseUrl,
      apiKey: apiKey,
      since: DateTime.utc(2026, 8, 1),
    );

    expect(rows, hasLength(1));
    expect(rows.single['category'], 'Food');
    expect(rows.single['narration'], '[upi]-[ref]-for dinner');
    // Bearer auth + date-only since param.
    expect(captured.headers['Authorization'], 'Bearer $apiKey');
    expect(captured.url.path, '/statements');
    expect(captured.url.queryParameters['since'], '2026-08-01');
  });

  test('fetchRows maps 401/403 to unauthorized errors', () async {
    final client = MockClient((_) async => http.Response('nope', 403));
    final api = StatementSyncApi(client: client);
    await expectLater(
      api.fetchRows(baseUrl: baseUrl, apiKey: apiKey),
      throwsA(isA<StatementSyncException>()
          .having((e) => e.unauthorized, 'unauthorized', isTrue)),
    );
  });

  test('fetchRows throws on non-200', () async {
    final client = MockClient((_) async => http.Response('boom', 500));
    final api = StatementSyncApi(client: client);
    await expectLater(
      api.fetchRows(baseUrl: baseUrl, apiKey: apiKey),
      throwsA(isA<StatementSyncException>()),
    );
  });

  test('fetchStatus returns ledger stats', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/status');
      return http.Response(
        jsonEncode({'statements': 3, 'rows': 42}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = StatementSyncApi(client: client);
    final status = await api.fetchStatus(baseUrl: baseUrl, apiKey: apiKey);
    expect(status['rows'], 42);
    expect(status['statements'], 3);
  });
}