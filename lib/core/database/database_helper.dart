import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'write_queue.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  final WriteQueue _writeQueue = WriteQueue();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rozz.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: (db) async {
        await db.execute('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA synchronous=NORMAL');
        final result = await db.rawQuery('PRAGMA integrity_check');
        if (result.first.values.first != 'ok') {
          throw Exception('Database integrity check failed');
        }
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        date             TEXT NOT NULL,
        amount           REAL NOT NULL,
        direction        TEXT NOT NULL,
        label_type       TEXT NOT NULL,
        recipient_name   TEXT,
        upi_id           TEXT,
        narration        TEXT,
        note             TEXT,
        category         TEXT,
        subcategory      TEXT,
        balance_after    REAL,
        source           TEXT,
        is_split         INTEGER DEFAULT 0,
        is_reversal      INTEGER DEFAULT 0,
        paired_id        INTEGER,
        upi_ref_number   TEXT UNIQUE,
        raw_sms          TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE split_items (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id   INTEGER NOT NULL REFERENCES transactions(id),
        item_name        TEXT NOT NULL,
        amount           REAL NOT NULL,
        category         TEXT,
        subcategory      TEXT,
        image_path       TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE upi_memory (
        upi_id           TEXT PRIMARY KEY,
        learned_category TEXT,
        learned_subcategory TEXT,
        recipient_name   TEXT,
        last_used_date   TEXT,
        usage_count      INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE mab_history (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        date                TEXT NOT NULL UNIQUE,
        end_of_day_balance  REAL NOT NULL,
        month               INTEGER NOT NULL,
        year                INTEGER NOT NULL,
        calculated_mab      REAL,
        zone                TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key               TEXT PRIMARY KEY,
        value             TEXT NOT NULL
      )
    ''');
  }

  Future<T> write<T>(Future<T> Function() operation) async {
    return await _writeQueue.add(operation);
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
