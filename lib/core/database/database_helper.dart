import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';
import 'write_queue.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static const int _version = 8;
  final WriteQueue _writeQueue = WriteQueue();

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      databaseFactory = databaseFactoryFfi;
      return await openDatabase(inMemoryDatabasePath, version: _version, onCreate: _onCreate);
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rozz_database.db');

    return await openDatabase(
      path,
      version: _version,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL');
        await db.rawQuery('PRAGMA synchronous=NORMAL');
        // Native (Kotlin) writes to the same DB file — avoid SQLITE_BUSY drops.
        await db.rawQuery('PRAGMA busy_timeout=5000');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_transactionsDdl);
    await db.execute(_mabDdl);
    await db.execute(_rawInboxDdl);
    await db.execute(_senderLabelsDdl);
    await db.execute(_appMetaDdl);
    await db.execute(_dismissedSubscriptionsDdl);
    await db.execute(_txDedupeIndexDdl);
    await _seedDismissedSubscriptions(db);
  }

  /// v1 had a corrupted transactions DDL (literal "\n" broke the category column),
  /// so existing installs need the table rebuilt. onUpgrade is idempotent and also
  /// covers the cold-start case where Kotlin created the DB file first (no onCreate).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('CREATE TABLE IF NOT EXISTS transactions_new $_transactionsBody');
    await db.execute('''
      INSERT INTO transactions_new (date, amount, direction, label_type, recipient_name, upi_id, balance_after, source, upi_ref_number, raw_sms, category)
      SELECT date, amount, direction, label_type, recipient_name, upi_id, balance_after, COALESCE(source, 'sms'), upi_ref_number, raw_sms, category FROM transactions
      WHERE EXISTS (SELECT 1 FROM transactions)
    ''');
    await db.execute('DROP TABLE IF EXISTS transactions');
    await db.execute('ALTER TABLE transactions_new RENAME TO transactions');
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

    if (oldVersion < 4) {
      // v4: sender_labels — user-defined identity for UPI senders.
      await db.execute(_senderLabelsDdl);
    }

    if (oldVersion < 5) {
      // v5: the old recipient regex crossed newlines and captured the WHOLE
      // SMS (or the own account) as the recipient name, breaking subscription
      // detection and sender identity. Re-derive clean merchant/sender names
      // from the stored raw SMS, and stash the account suffix ("4736") for the
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
      // Account suffix from any SMS mentioning "A/c XXXX" (or "A/c XX4736").
      final suffix = await _extractAccountSuffix(db);
      if (suffix != null) {
        await db.insert('app_meta', {'key': 'account_suffix', 'value': suffix},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    if (oldVersion < 6) {
      // v6: drop the stale own-account label ("hdfc bank a/c xx4736" →
      // "papa") left over from before the v5 sender split. With stem-based
      // label matching its generic stem ("bank") now falsely names unrelated
      // VPAs like "918075637374@wahdfcbank".
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

  /// Last 4 digits of the account number from any SMS, e.g. "A/c XX4736" → 4736.
  static Future<String?> _extractAccountSuffix(Database db) async {
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
        category         TEXT
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
  /// "kk9396@okhdfcbank" -> "father".
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

  Future<void> _seedDismissedSubscriptions(Database db) async {
    final batch = db.batch();
    for (final key in _seededDismissedSubscriptions) {
      batch.insert('dismissed_subscriptions', {'merchant_key': key},
          conflictAlgorithm: ConflictAlgorithm.ignore);
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

  /// For read operations
  Future<dynamic> query(Future<dynamic> Function(Database db) operation) async {
    final db = await database;
    return await operation(db);
  }

  /// For write operations (queued)
  Future<dynamic> write(Future<dynamic> Function(Database db) operation) async {
    return await _writeQueue.add(() async {
      final db = await database;
      return await operation(db);
    });
  }

  /// Generic execute
  Future<dynamic> execute(Future<dynamic> Function(Database db) operation) async {
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