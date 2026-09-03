import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:rozz/features/statement_upload/domain/repositories/statement_sync_repository.dart'
    show StatementSyncException;

/// HTTP client for the ROZZ statement server's sync API.
///
/// The server serves ONLY redacted rows (narration scrubbed, refs/VPAs kept
/// as dedicated fields for linking + dedupe). The app pulls incrementally
/// with its stored last-sync date; the server's fingerprint makes re-syncs
/// idempotent.
class StatementSyncApi {
  final http.Client _client;

  StatementSyncApi({http.Client? client}) : _client = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 20);

  /// Fetches statement rows newer than [since] (server-side date filter).
  /// Throws [StatementSyncException] on auth failure, network failure or a
  /// non-200 response.
  Future<List<Map<String, dynamic>>> fetchRows({
    required String baseUrl,
    required String apiKey,
    DateTime? since,
  }) async {
    final uri = Uri.parse('$baseUrl/statements').replace(
      queryParameters: {
        if (since != null) 'since': since.toIso8601String().substring(0, 10),
      },
    );
    final response = await _client
        .get(uri, headers: {'Authorization': 'Bearer $apiKey'})
        .timeout(_timeout);
    if (response.statusCode == 403 || response.statusCode == 401) {
      throw StatementSyncException.unauthorized();
    }
    if (response.statusCode != 200) {
      throw StatementSyncException(
        'Server responded ${response.statusCode}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = data['rows'] as List<dynamic>? ?? const [];
    return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  /// Server ledger stats (statement count, row count, last processed).
  Future<Map<String, dynamic>> fetchStatus({
    required String baseUrl,
    required String apiKey,
  }) async {
    final uri = Uri.parse('$baseUrl/status');
    final response = await _client
        .get(uri, headers: {'Authorization': 'Bearer $apiKey'})
        .timeout(_timeout);
    if (response.statusCode == 403 || response.statusCode == 401) {
      throw StatementSyncException.unauthorized();
    }
    if (response.statusCode != 200) {
      throw StatementSyncException(
        'Server responded ${response.statusCode}',
      );
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
}