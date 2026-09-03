/// Outcome of one statement sync pull.
class StatementSyncResult {
  final int fetched;
  final int inserted;
  final int duplicates;

  /// ISO-8601 UTC timestamp of this sync (also persisted in app_meta).
  final String lastSync;

  const StatementSyncResult({
    required this.fetched,
    required this.inserted,
    required this.duplicates,
    required this.lastSync,
  });
}

/// Saved sync configuration + last-sync state, for the UI.
class StatementSyncConfig {
  final String serverUrl;
  final bool apiKeySet;
  final DateTime? lastSync;

  const StatementSyncConfig({
    required this.serverUrl,
    required this.apiKeySet,
    this.lastSync,
  });
}

/// Pulls parsed statement rows from the ROZZ statement server and ingests
/// them into the local ledger through the existing transaction path (dedupe
/// via the transactions unique index + the uploaded_rows fingerprints).
abstract class StatementSyncRepository {
  Future<StatementSyncConfig> loadConfig();

  Future<void> saveConfig({
    required String serverUrl,
    required String apiKey,
  });

  Future<StatementSyncResult> syncNow();
}

/// Failure from the statement server or its sync pipeline.
class StatementSyncException implements Exception {
  final String message;
  final bool unauthorized;

  const StatementSyncException(this.message, {this.unauthorized = false});

  const StatementSyncException.unauthorized()
      : message =
            'The server rejected the API key. Check the URL and key in '
            'Statement Sync settings.',
        unauthorized = true;

  @override
  String toString() => message;
}