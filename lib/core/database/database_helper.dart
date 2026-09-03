import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:rozz/core/security/secure_storage_service.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';
import 'write_queue.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static sqlcipher.Database? _database;
  static const int _version = 11;
  final WriteQueue _writeQueue = WriteQueue();
  String? _encryptionKey;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<sqlcipher.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<sqlcipher.Database> _initDatabase() async {
    // Test / web: use unencrypted in-memory DB (no native SQLCipher support)
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      ffi.databaseFactory = ffi.databaseFactoryFfi;
      return await ffi.openDatabase(
        ffi.inMemoryDatabasePath,
        version: _version,
        onCreate: _onCreate,
      );
    }

    _encryptionKey = await _getOrCreateEncryptionKey();
    final dbPath = await sqlcipher.getDatabasesPath();
    final path = join(dbPath, 'rozz_database.db');

    try {
      // Pre-SQLCipher installs keep the ledger plaintext ("SQLite format 3\0"
      // header). Detect it BEFORE the keyed open: a leftover rollback journal
      // from the plaintext era makes the keyed open throw open_failed
      // (CANTOPEN, 14) instead of the NOTADB (26) the legacy migration keyed
      // on — which silently bricked every read on those installs.
      if (await _isPlaintext(path)) {
        await _encryptExistingDatabase(path, _encryptionKey!);
      } else if (await File(path).exists()) {
        // Existing encrypted DB: it must decrypt with the current key AND
        // carry the ledger schema. If either fails, the DB is unrecoverable
        // as-is — a Keystore key lost after restore/update/hard-kill (SQLCipher
        // code 26 "file is not a database"), or the schema-less version-2
        // artifact the old _repairZeroVersion stamped on fresh installs
        // ("no such table" on every open). Quarantine it and start a fresh
        // ledger instead of bricking the app on a generic load error.
        if (await _isHealthyLedger(path, _encryptionKey!)) {
          await _repairZeroVersion(path, _encryptionKey!);
        } else {
          await _quarantineBrokenDatabase(path);
        }
      }
      return await _openEncrypted(path);
    } on sqlcipher.DatabaseException catch (e) {
      if (!_isNotADatabase(e)) rethrow;
      // v8 and earlier kept the ledger in plaintext — SQLCipher can't open
      // that with a key, so convert it in place before the first encrypted
      // open. Without this, every existing install would lose its ledger.
      await _encryptExistingDatabase(path, _encryptionKey!);
      return _openEncrypted(path);
    }
  }

  /// True when [path] decrypts with [key] AND carries the ledger schema.
  /// False on a key mismatch (SQLCipher code 26) or on the schema-less
  /// version-2 artifact from the old _repairZeroVersion bug — both are
  /// unrecoverable with the current key and must be quarantined.
  Future<bool> _isHealthyLedger(String path, String key) async {
    try {
      final db = await _openWithKey(path, password: key);
      try {
        final rows = await db.rawQuery(
          "SELECT name FROM sqlite_schema WHERE type='table' AND name='transactions'",
        );
        return rows.isNotEmpty;
      } finally {
        await db.close();
      }
    } on sqlcipher.DatabaseException {
      // Can't decrypt or read the file with the current key — not ours.
      return false;
    }
  }

  /// Moves an unreadable ledger aside (kept for forensics / manual recovery —
  /// the data was unrecoverable with the current key anyway) and clears WAL
  /// sidecars so the next open starts a clean, freshly-created ledger.
  Future<void> _quarantineBrokenDatabase(String path) async {
    final ts = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    final backup = '$path.broken-$ts';
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final file = File('$path$suffix');
      if (!await file.exists()) continue;
      await file.rename('$backup$suffix');
    }
    debugPrint('ROZZ: quarantined unreadable ledger to $backup; starting fresh');
  }

  /// Test seam — the SQLCipher plugin is a method channel that does not exist
  /// under `flutter test`; ffi stands in there (passwords are ignored, so the
  /// wrong-key branch can't be simulated — the schema checks still hold).
  @visibleForTesting
  static Future<sqlcipher.Database> Function(String path, {String? password})
      dbOpenerForTest = defaultDbOpener;

  @visibleForTesting
  static Future<sqlcipher.Database> defaultDbOpener(
    String path, {
    String? password,
  }) =>
      sqlcipher.openDatabase(path, password: password);

  Future<sqlcipher.Database> _openWithKey(String path, {String? password}) =>
      dbOpenerForTest(path, password: password);

  @visibleForTesting
  Future<void> applyUpgradeForTest(sqlcipher.Database db, int oldVersion) =>
      _onUpgrade(db, oldVersion, _version);

  @visibleForTesting
  Future<void> repairZeroVersionForTest(String path, String key) =>
      _repairZeroVersion(path, key);

  @visibleForTesting
  Future<bool> isHealthyLedgerForTest(String path, String key) =>
      _isHealthyLedger(path, key);

  @visibleForTesting
  Future<void> quarantineBrokenDatabaseForTest(String path) =>
      _quarantineBrokenDatabase(path);

  Future<sqlcipher.Database> _openEncrypted(String path) {
    return sqlcipher.openDatabase(
      path,
      password: _encryptionKey!,
      version: _version,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL');
        await db.rawQuery('PRAGMA synchronous=NORMAL');
        await db.rawQuery('PRAGMA busy_timeout=5000');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// SQLCipher cannot open a plaintext SQLite file with a key ("file is not a
  /// database", code 26). The documented plaintext→encrypted path is to open
  /// the file in plaintext mode (empty key), attach an encrypted copy, export
  /// into it, then swap the files. `PRAGMA rekey` does NOT work here — it only
  /// re-keys an already-encrypted database.
  Future<void> _encryptExistingDatabase(String path, String key) async {
    final encPath = '$path.enc';
    final encFile = File(encPath);
    if (await encFile.exists()) await encFile.delete();

    // A hot rollback journal from the plaintext era can't be rolled back by
    // SQLCipher's plaintext-compat mode (readonly). The DB header itself is
    // valid, so drop the sidecars — the whole file is being replaced below.
    for (final suffix in ['-journal', '-wal', '-shm']) {
      final side = File('$path$suffix');
      if (await side.exists()) await side.delete();
    }

    // Empty password = SQLCipher plaintext-compatibility mode.
    final plain = await sqlcipher.openDatabase(path);
    try {
      // sqlcipher_export copies schema + data but NOT the user_version header,
      // so without this the encrypted file would reopen as version 0 and sqflite
      // would run onCreate against the exported tables ("already exists").
      final oldVersion = await plain.getVersion();
      await plain.execute("ATTACH DATABASE '$encPath' AS encrypted KEY '$key'");
      // sqlcipher_export is a SELECT — sqflite's execute() rejects queries on
      // Android ("rawQuery only"), so read the result, don't execute it.
      await plain.rawQuery("SELECT sqlcipher_export('encrypted')");
      await plain.execute('PRAGMA encrypted.user_version = $oldVersion');
      await plain.execute('DETACH DATABASE encrypted');
    } finally {
      await plain.close();
    }

    // The encrypted copy becomes the live DB; drop plaintext + any sidecars.
    await File(path).delete();
    await encFile.rename(path);
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final side = File('$path$suffix');
      if (await side.exists()) await side.delete();
    }
  }

  /// Matches SQLITE_NOTADB (26) plus the two message shapes SQLCipher uses
  /// when a file can't be opened with the given key.
  static bool _isNotADatabase(sqlcipher.DatabaseException e) {
    final msg = e.toString().toLowerCase();
    return (e.getResultCode() ?? 0) == 26 ||
        msg.contains('not a database') ||
        msg.contains('file is encrypted');
  }  /// An encrypted DB stamped user_version=0 (from an early buggy export)
  /// makes sqflite fire onCreate against existing tables. Detect and re-stamp
  /// it to 2 — oldVersion=0 would run onCreate; 2 skips the v1 table rebuild
  /// yet still walks every later onUpgrade migration (all IF NOT EXISTS / data
  /// -preserving) over the exported schema.
  Future<void> _repairZeroVersion(String path, String key) async {
    // Fresh install: nothing to repair. SQLite CREATES the file on open —
    // doing that here stamped an empty schema-less DB as version 2, and the
    // very first real open then crashed in onUpgrade ("no such table:
    // transactions"), bricking every fresh install.
    if (!await File(path).exists()) return;
    final db = await sqlcipher.openDatabase(path, password: key);
    try {
      if (await db.getVersion() != 0) return;
      await db.setVersion(2);
    } finally {
      await db.close();
    }
  }

  /// True when [path] is a plaintext SQLite file (SQLCipher-less legacy DB):
  /// the 16-byte magic "SQLite format 3\0". Encrypted SQLCipher files have
  /// random bytes there and must NOT be re-exported.
  static Future<bool> _isPlaintext(String path) async {
    try {
      final raf = await File(path).open(mode: FileMode.read);
      try {
        final header = await raf.read(16);
        if (header.length != 16) return false;
        return String.fromCharCodes(header) == 'SQLite format 3\u0000';
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Generates or retrieves the 256-bit database encryption key.
  ///
  /// Lives in Keystore-backed secure storage so a disk image or rooted device
  /// can't read key and ciphertext together. Legacy builds kept a plaintext
  /// `.db_key` file next to the DB — migrate it in once, then delete it.
  Future<String> _getOrCreateEncryptionKey() async {
    const storageKey = 'db_encryption_key';
    final storage = SecureStorageService();

    final stored = await storage.readValue(storageKey);
    if (stored != null && stored.isNotEmpty) return stored;

    final dbPath = await sqlcipher.getDatabasesPath();
    final keyFile = File('$dbPath/.db_key');
    if (await keyFile.exists()) {
      final legacy = (await keyFile.readAsString()).trim();
      if (legacy.isNotEmpty) {
        await storage.writeValue(storageKey, legacy);
        await keyFile.delete();
        return legacy;
      }
    }

    // Generate new 256-bit key using Dart's cryptographically secure RNG.
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64Url.encode(values);
    await storage.writeValue(storageKey, key);
    return key;
  }

  Future<void> _onCreate(sqlcipher.Database db, int version) async {
    await db.execute(_transactionsDdl);
    await db.execute(_mabDdl);
    await db.execute(_rawInboxDdl);
    await db.execute(_senderLabelsDdl);
    await db.execute(_appMetaDdl);
    await db.execute(_dismissedSubscriptionsDdl);
    await db.execute(_merchantsDdl);
    await db.execute(_merchantAliasesDdl);
    await db.execute(_statementUploadsDdl);
    await db.execute(_uploadedRowsDdl);
    await db.execute(_txDedupeIndexDdl);
    await db.execute(_txDateIndexDdl);
    await db.execute(_txMerchantIndexDdl);
    await _seedDismissedSubscriptions(db);
  }

  /// v1 had a corrupted transactions DDL (literal "\n" broke the category column),
  /// so v1 installs need the table rebuilt. For v2+ the schema is already correct;
  /// the rebuild is skipped so a 50k-row copy doesn't run on every future bump.
  /// The guard also covers the cold-start case where Kotlin created the DB file
  /// first (no onCreate → onUpgrade(0, newVersion)).
  Future<void> _onUpgrade(sqlcipher.Database db, int oldVersion, int newVersion) async {
    // Self-heal (defense in depth behind the _isHealthyLedger quarantine):
    // installs that carry the schema-less version-2 artifact from the old
    // _repairZeroVersion bug have NO tables at all. Recreate the full current
    // schema so every migration below can run instead of crashing on
    // 'no such table: transactions' and bricking the app.
    if (!await _tableExists(db, 'transactions')) {
      await db.execute(_transactionsDdl);
      await db.execute(_mabDdl);
      await db.execute(_rawInboxDdl);
      await db.execute(_senderLabelsDdl);
      await db.execute(_appMetaDdl);
      await db.execute(_dismissedSubscriptionsDdl);
      await db.execute(_merchantsDdl);
      await db.execute(_merchantAliasesDdl);
      await db.execute(_statementUploadsDdl);
      await db.execute(_uploadedRowsDdl);
      await db.execute(_txDedupeIndexDdl);
      await db.execute(_txDateIndexDdl);
      await db.execute(_txMerchantIndexDdl);
      await _seedDismissedSubscriptions(db);
    }

    if (oldVersion < 2) {
      await db.execute('CREATE TABLE IF NOT EXISTS transactions_new $_transactionsBody');
      await db.execute('''
        INSERT INTO transactions_new (date, amount, direction, label_type, recipient_name, upi_id, balance_after, source, upi_ref_number, raw_sms, category)
        SELECT date, amount, direction, label_type, recipient_name, upi_id, balance_after, COALESCE(source, 'sms'), upi_ref_number, raw_sms, category FROM transactions
        WHERE EXISTS (SELECT 1 FROM transactions)
      ''');
      await db.execute('DROP TABLE IF EXISTS transactions');
      await db.execute('ALTER TABLE transactions_new RENAME TO transactions');
    }
    await db.execute(_mabDdl);
    await db.execute(_rawInboxDdl);
    await db.execute(_dismissedSubscriptionsDdl);

    if (oldVersion < 3) {
      // v3: purge non-transaction alerts (daily balance advice + low-balance
      // warnings) that the parser previously imported as transactions, then
      // rebuild the dedupe index so NULL-balance rows can't duplicate.
      await db.delete(
        'transactions',
        where: 'raw_sms LIKE ? OR raw_sms LIKE ?',
        whereArgs: ['%as on yesterday%', '%gone below minimum limit%'],
      );
      await db.execute('''
        DELETE FROM transactions WHERE id NOT IN (
          SELECT MIN(id) FROM transactions
          GROUP BY direction, amount, date, COALESCE(balance_after, -1), raw_sms
        )
      ''');
      await db.execute('DROP INDEX IF EXISTS idx_tx_dedupe');
      await db.execute(_txDedupeIndexDdl);
    } else {
      await db.execute(_txDedupeIndexDdl);
    }

    if (oldVersion < 10) {
      // v10: index on transaction date. All list reads sort by date DESC and
      // month loads use a date range, so a bare date index makes every screen
      // load index-backed instead of a full scan.
      await db.execute(_txDateIndexDdl);
    }

    if (oldVersion < 11) {
      // v11: merchant identity + user narration. The cold-start path can reach
      // here with the transactions table ALREADY carrying the new columns
      // (v0 -> v2 table rebuild below re-creates the table from the current
      // body), so the ALTERs are column-existence-guarded — SQLite has no
      // IF NOT EXISTS for ADD COLUMN.
      await _ensureColumn(
        db,
        'transactions',
        'merchant_key',
        'ALTER TABLE transactions ADD COLUMN merchant_key TEXT',
      );
      await _ensureColumn(
        db,
        'transactions',
        'user_narration',
        'ALTER TABLE transactions ADD COLUMN user_narration TEXT',
      );
      await db.execute(_merchantsDdl);
      await db.execute(_merchantAliasesDdl);
      await db.execute(_statementUploadsDdl);
      await db.execute(_uploadedRowsDdl);
      await db.execute(_txMerchantIndexDdl);
    }

    if (oldVersion < 4) {
      // v4: sender_labels — user-defined identity for UPI senders.
      await db.execute(_senderLabelsDdl);
    }

    if (oldVersion < 5) {
      // v5: the old recipient regex crossed newlines and captured the WHOLE
      // SMS (or the own account) as the recipient name, breaking subscription
      // detection and sender identity. Re-derive clean merchant/sender names
      // from the stored raw SMS, and stash the account suffix ("4321") for the
      // balance hero.
      await db.execute(_appMetaDdl);
      final parser = SmsParser();
      final rows = await db.query('transactions',
          columns: ['id', 'direction', 'recipient_name', 'raw_sms']);
      for (final row in rows) {
        final id = row['id'];
        final rawSms = row['raw_sms'] as String?;
        if (rawSms == null || rawSms.trim().isEmpty) continue;
        final oldName = row['recipient_name'] as String?;
        final looksBroken = (oldName?.contains('\n') ?? false) ||
            (oldName != null && _accountRe.hasMatch(oldName));
        if (looksBroken) {
          final parsed = parser.parse(rawSms);
          final newName = parsed?['recipient_name'] as String?;
          if (newName != null && newName != oldName) {
            await db.update(
              'transactions',
              {'recipient_name': newName},
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      }
      // Account suffix from any SMS mentioning "A/c XXXX" (or "A/c XX4321").
      final suffix = await _extractAccountSuffix(db);
      if (suffix != null) {
        await db.insert('app_meta', {'key': 'account_suffix', 'value': suffix},
            conflictAlgorithm: sqlcipher.ConflictAlgorithm.replace);
      }
    }

    if (oldVersion < 6) {
      // v6: drop the stale own-account label ("hdfc bank a/c xx4321" →
      // "papa") left over from before the v5 sender split. With stem-based
      // label matching its generic stem ("bank") now falsely names unrelated
      // VPAs like "919812345678@wahdfcbank".
      await db.delete('sender_labels',
          where: 'key LIKE ?', whereArgs: ['hdfc bank a/c%']);
    }

    if (oldVersion < 7) {
      // v7: purge balance-advice SMS that the old parser ingested as bogus
      // transactions ("Available Bal in A/c ... is INR X as on DD-MON-YY" —
      // amount = the balance, direction unknown). They are snapshots, not
      // movements; the ledger keeps only real transactions. (LIKE is
      // case-insensitive for ASCII in SQLite.)
      await db.delete('transactions', where: "raw_sms LIKE 'Available Bal%'");
    }

    if (oldVersion < 8) {
      // v8: dismissed_subscriptions + seed the user-reported false positives
      // (monthly haircut, local merchants). The table is created above; seed
      // only here so existing installs stop showing them without a UI tap.
      await _seedDismissedSubscriptions(db);
    }
  }

  static final _accountRe = RegExp(r'a\/?c\b', caseSensitive: false);

  /// Last 4 digits of the account number from any SMS, e.g. "A/c XX4321" → 4321.
  static Future<String?> _extractAccountSuffix(sqlcipher.Database db) async {
    final rows = await db.rawQuery(
      "SELECT raw_sms FROM transactions WHERE raw_sms LIKE '%A/c%' OR raw_sms LIKE '%a/c%' LIMIT 20",
    );
    final re = RegExp(r'a\/?c\s*(?:xx)?(\d{4})\b', caseSensitive: false);
    for (final row in rows) {
      final sms = row['raw_sms'] as String?;
      if (sms == null) continue;
      final m = re.firstMatch(sms);
      if (m != null) return m.group(1);
    }
    return null;
  }

  static const String _transactionsBody = '''
      (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        date             TEXT    NOT NULL,
        amount           REAL    NOT NULL,
        direction        TEXT    NOT NULL,
        label_type       TEXT    NOT NULL,
        recipient_name   TEXT,
        upi_id           TEXT,
        balance_after    REAL,
        source           TEXT    NOT NULL,
        upi_ref_number   TEXT UNIQUE,
        raw_sms          TEXT,
        category         TEXT,
        merchant_key     TEXT,
        user_narration   TEXT
      )
  ''';

  static const String _transactionsDdl = 'CREATE TABLE transactions $_transactionsBody';

  static const String _mabDdl = '''
      CREATE TABLE IF NOT EXISTS mab_history (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        date               TEXT    NOT NULL UNIQUE,
        end_of_day_balance REAL    NOT NULL,
        month              INTEGER NOT NULL,
        year               INTEGER NOT NULL
      )
  ''';

  static const String _rawInboxDdl = '''
      CREATE TABLE IF NOT EXISTS raw_inbox (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        sender       TEXT,
        body         TEXT NOT NULL,
        received_at  INTEGER NOT NULL
      )
  ''';

  /// User-defined label for a sender key (UPI ID / VPA / phone digits), e.g.
  /// "tt9396@okhdfcbank" -> "father".
  static const String _senderLabelsDdl = '''
      CREATE TABLE IF NOT EXISTS sender_labels (
        key    TEXT PRIMARY KEY,
        label  TEXT NOT NULL
      )
  ''';

  /// Tiny key-value store for derived app facts (e.g. the account suffix).
  static const String _appMetaDdl = '''
      CREATE TABLE IF NOT EXISTS app_meta (
        key    TEXT PRIMARY KEY,
        value  TEXT NOT NULL
      )
  ''';

  /// Canonical merchant payee — "the central ID" every raw spelling of a
  /// payee resolves to. `description` is the user's canonical narration
  /// ("dinner"); `conflict` is set when the user gave two DIFFERENT
  /// descriptions for the same merchant — then auto-apply stops and the UI
  /// asks instead of clobbering.
  static const String _merchantsDdl = '''
      CREATE TABLE IF NOT EXISTS merchants (
        merchant_key   TEXT PRIMARY KEY,
        canonical_name TEXT NOT NULL,
        category       TEXT,
        description    TEXT,
        source         TEXT NOT NULL,
        conflict       INTEGER NOT NULL DEFAULT 0,
        tx_count       INTEGER NOT NULL DEFAULT 0,
        last_seen      TEXT,
        updated_at     TEXT NOT NULL
      )
  ''';

  /// One normalized raw identity string -> canonical merchant. `alias_key` is
  /// a MerchantKey slug / VPA local part; `kind` says where it came from.
  static const String _merchantAliasesDdl = '''
      CREATE TABLE IF NOT EXISTS merchant_aliases (
        alias_key    TEXT PRIMARY KEY,
        merchant_key TEXT NOT NULL,
        kind         TEXT NOT NULL,
        created_at   TEXT NOT NULL
      )
  ''';

  /// One row per uploaded/pasted statement (for undo + audit).
  static const String _statementUploadsDdl = '''
      CREATE TABLE IF NOT EXISTS statement_uploads (
        upload_id   TEXT PRIMARY KEY,
        file_name   TEXT NOT NULL,
        uploaded_at TEXT NOT NULL
      )
  ''';

  /// Fingerprinted statement rows so re-uploading the same statement is a
  /// provable no-op, plus the ledger linkage for undo.
  static const String _uploadedRowsDdl = '''
      CREATE TABLE IF NOT EXISTS uploaded_rows (
        fingerprint TEXT PRIMARY KEY,
        upload_id   TEXT NOT NULL,
        tx_id       INTEGER,
        action      TEXT NOT NULL
      )
  ''';

  /// Subscriptions the user dismissed as not-a-subscription (a monthly haircut,
  /// a local merchant). Keyed by the same slug ComputeSubscriptions groups on.
  static const String _dismissedSubscriptionsDdl = '''
      CREATE TABLE IF NOT EXISTS dismissed_subscriptions (
        merchant_key TEXT PRIMARY KEY
      )
  ''';

  /// User-reported false positives (a monthly haircut, local merchants) —
  /// seeded once so they stop showing immediately; removable in the UI.
  static const List<String> _seededDismissedSubscriptions = [
    'amirhusain',
    'gogoldnr',
    'jeevin',
    'jeejo',
  ];

  Future<void> _seedDismissedSubscriptions(sqlcipher.Database db) async {
    final batch = db.batch();
    for (final key in _seededDismissedSubscriptions) {
      batch.insert('dismissed_subscriptions', {'merchant_key': key},
          conflictAlgorithm: sqlcipher.ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  /// The last 4 digits of the user's account, derived from their SMS.
  Future<String?> accountSuffix() async {
    try {
      final result = await query((db) async {
        return await db.query('app_meta',
            where: 'key = ?', whereArgs: ['account_suffix']);
      });
      if (result.isEmpty) return null;
      return (result.first['value'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }

  /// Ref-less transactions (ATM, MAB fine) can't dedupe on upi_ref_number;
  /// balance_after breaks same-day/same-amount ties. COALESCE makes NULL-balance
  /// rows dedupe too (SQLite treats NULLs as distinct in unique indexes), and
  /// raw_sms makes the key the full message text — identical SMS = same txn.
  static const String _txDedupeIndexDdl =
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_tx_dedupe ON transactions(direction, amount, date, COALESCE(balance_after, -1), raw_sms)';

  /// Every transaction read sorts by date DESC (list, month, balance), so a
  /// bare date index turns those full scans into index-backed orderings.
  static const String _txDateIndexDdl =
      'CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(date DESC)';

  /// Merchant propagation + statement linking touch every row of a merchant in
  /// one UPDATE — this index keeps those bulk writes indexed instead of a scan.
  static const String _txMerchantIndexDdl =
      'CREATE INDEX IF NOT EXISTS idx_tx_merchant ON transactions(merchant_key)';

  /// SQLite can't express `ADD COLUMN IF NOT EXISTS`; guard v11 ALTERs with a
  /// PRAGMA table_info probe so cold-start paths that already carry the column
  /// never double-add it.
  static Future<void> _ensureColumn(
    sqlcipher.Database db,
    String table,
    String column,
    String alterDdl,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final has = info.any((row) => row['name'] == column);
    if (!has) await db.execute(alterDdl);
  }

  static Future<bool> _tableExists(sqlcipher.Database db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_schema WHERE type='table' AND name = ?",
      [table],
    );
    return rows.isNotEmpty;
  }

  /// For read operations
  Future<dynamic> query(Future<dynamic> Function(sqlcipher.Database db) operation) async {
    final db = await database;
    return await operation(db);
  }

  /// For write operations (queued)
  Future<dynamic> write(Future<dynamic> Function(sqlcipher.Database db) operation) async {
    return await _writeQueue.add(() async {
      final db = await database;
      return await operation(db);
    });
  }

  /// Generic execute
  Future<dynamic> execute(Future<dynamic> Function(sqlcipher.Database db) operation) async {
    final db = await database;
    return await operation(db);
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}