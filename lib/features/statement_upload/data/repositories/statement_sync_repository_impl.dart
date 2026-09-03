import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/core/security/secure_storage_service.dart';
import 'package:rozz/features/statement_upload/data/datasources/statement_sync_api.dart';
import 'package:rozz/features/statement_upload/domain/repositories/statement_sync_repository.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

/// Default server address shown in the UI until the user overrides it.
const String defaultStatementServerUrl = 'https://your-server.example.com';

class StatementSyncRepositoryImpl implements StatementSyncRepository {
  static const String urlStorageKey = 'STATEMENT_SERVER_URL';
  static const String apiKeyStorageKey = 'STATEMENT_API_KEY';
  static const String lastSyncMetaKey = 'statement_last_sync';

  /// Prefix so sync fingerprints can never collide with other upload flows.
  static const String _fingerprintPrefix = 'sync:';

  final SecureStorageService _secureStorage;
  final StatementSyncApi _api;
  final TransactionLocalDatasource _transactions;
  final DatabaseHelper _databaseHelper;

  StatementSyncRepositoryImpl({
    required SecureStorageService secureStorage,
    required StatementSyncApi api,
    required TransactionLocalDatasource transactions,
    required DatabaseHelper databaseHelper,
  })  : _secureStorage = secureStorage,
        _api = api,
        _transactions = transactions,
        _databaseHelper = databaseHelper;

  @override
  Future<StatementSyncConfig> loadConfig() async {
    String? url;
    String? apiKey;
    try {
      url = await _secureStorage.readValue(urlStorageKey);
      apiKey = await _secureStorage.readValue(apiKeyStorageKey);
    } catch (e) {
      // Keystore read failure — treat as not configured.
    }
    return StatementSyncConfig(
      serverUrl: (url == null || url.isEmpty)
          ? defaultStatementServerUrl
          : url,
      apiKeySet: apiKey != null && apiKey.isNotEmpty,
      lastSync: await _lastSync(),
    );
  }

  @override
  Future<void> saveConfig({
    required String serverUrl,
    required String apiKey,
  }) async {
    final url = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) {
      throw const StatementSyncException('Server URL cannot be empty.');
    }
    await _secureStorage.writeValue(urlStorageKey, url);
    if (apiKey.trim().isNotEmpty) {
      await _secureStorage.writeValue(apiKeyStorageKey, apiKey.trim());
    }
  }

  @override
  Future<StatementSyncResult> syncNow() async {
    final config = await loadConfig();
    final apiKey = await _readApiKeyOrNull();
    if (apiKey == null || apiKey.isEmpty) {
      throw const StatementSyncException(
        'No API key saved yet — set the server URL and key first.',
      );
    }
    if (config.serverUrl == defaultStatementServerUrl) {
      throw const StatementSyncException(
        'Set your statement server URL first (Settings → Statement Sync).',
      );
    }

    final rows = await _api.fetchRows(
      baseUrl: config.serverUrl,
      apiKey: apiKey,
      since: config.lastSync,
    );

    var inserted = 0;
    var duplicates = 0;
    for (final row in rows) {
      final fingerprint = row['fingerprint'] as String?;
      final alreadySynced = fingerprint != null &&
          await _isFingerprintStored(_fingerprintPrefix + fingerprint);
      if (alreadySynced) {
        duplicates++;
        continue;
      }
      final tx = _toTransaction(row);
      try {
        await _transactions.insertTransaction(tx);
      } catch (e) {
        // Unique-index collision with an SMS-ingested row (same UPI ref) —
        // that's a duplicate, not an error.
        duplicates++;
        continue;
      }
      if (fingerprint != null) {
        await _recordFingerprint(
          _fingerprintPrefix + fingerprint,
          row['statement_id'] as String? ?? 'sync',
        );
      }
      inserted++;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await _databaseHelper.write((db) async {
      await db.insert(
        'app_meta',
        {'key': lastSyncMetaKey, 'value': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    return StatementSyncResult(
      fetched: rows.length,
      inserted: inserted,
      duplicates: duplicates,
      lastSync: now,
    );
  }

  /// Server row JSON → app TransactionModel. The redacted narration rides in
  /// rawSms so the app's dedupe index (direction, amount, date, balance,
  /// raw_sms) treats identical re-syncs as no-ops; the ref rides in
  /// upi_ref_number so the UNIQUE index catches the same transaction already
  /// ingested from an SMS.
  static TransactionModel _toTransaction(Map<String, dynamic> row) {
    final vpa = row['vpa'] as String?;
    final payee = row['payee'] as String?;
    return TransactionModel(
      date: row['date'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      amount: (row['amount'] as num).toDouble(),
      direction: row['direction'] as String,
      labelType: row['label_type'] as String? ?? 'statement',
      recipientName: (payee == null || payee.isEmpty) ? vpa : payee,
      upiId: vpa,
      balanceAfter: (row['balance_after'] as num?)?.toDouble(),
      source: 'statement',
      upiRefNumber: row['ref'] as String?,
      rawSms: row['narration'] as String?,
      category: row['category'] as String?,
    );
  }

  Future<DateTime?> _lastSync() async {
    try {
      final result = await _databaseHelper.query((db) async {
        return await db.query(
          'app_meta',
          where: 'key = ?',
          whereArgs: [lastSyncMetaKey],
          limit: 1,
        );
      });
      if (result.isEmpty) return null;
      return DateTime.tryParse(result.first['value'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readApiKeyOrNull() async {
    try {
      return await _secureStorage.readValue(apiKeyStorageKey);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isFingerprintStored(String fingerprint) async {
    try {
      final result = await _databaseHelper.query((db) async {
        return await db.query(
          'uploaded_rows',
          where: 'fingerprint = ?',
          whereArgs: [fingerprint],
          limit: 1,
        );
      });
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _recordFingerprint(
    String fingerprint,
    String uploadId,
  ) async {
    await _databaseHelper.write((db) async {
      await db.insert(
        'uploaded_rows',
        {
          'fingerprint': fingerprint,
          'upload_id': uploadId,
          'action': 'sync',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }
}