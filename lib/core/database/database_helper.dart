import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'write_queue.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static const int _version = 3;
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
      onOpen: (db) async {
        final result = await db.rawQuery('PRAGMA integrity_check');
        if (result.isNotEmpty && result.first.values.isNotEmpty && result.first.values.first != 'ok') {
          throw Exception('Database integrity check failed');
        }
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_transactionsDdl);
    await db.execute(_mabDdl);
    await db.execute(_rawInboxDdl);
    await db.execute(_txDedupeIndexDdl);
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