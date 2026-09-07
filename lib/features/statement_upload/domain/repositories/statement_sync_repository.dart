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

/// Outcome of one direct statement import (paste / shared text).
class StatementImportResult {
  /// Rows the parser recognized (confident or not).
  final int parsed;

  /// Rows that became new ledger transactions.
  final int inserted;

  /// Rows already in the ledger (same ref, or same day+amount+direction).
  final int duplicates;

  /// Rows kept but flagged unparseable — shown, never dropped.
  final int unparsed;

  /// The statement's final closing balance — after import this is the
  /// balance engine's anchor (the bank's own number).
  final double? lastBalance;

  /// Day (yyyy-MM-dd) of [lastBalance].
  final String? lastBalanceDate;

  const StatementImportResult({
    required this.parsed,
    required this.inserted,
    required this.duplicates,
    required this.unparsed,
    this.lastBalance,
    this.lastBalanceDate,
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

  /// Parses raw statement text (PDF text copied out of a viewer, or pasted
  /// from any source) and ingests the rows into the local ledger with the
  /// same dedupe guarantees as the server sync. Their closing balances
  /// become balance anchors — the strongest anchors the app can have.
  Future<StatementImportResult> importStatementText(String text);
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