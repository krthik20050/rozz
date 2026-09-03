import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Regression tests for the two DB-bricking bugs found on the emulator:
///
/// 1. `_repairZeroVersion` created (not just repaired) the DB on fresh
///    installs, stamping an empty schema-less database with user_version 2 —
///    then `onUpgrade(2, 11)` crashed on `DELETE FROM transactions`
///    ("no such table") and EVERY open failed forever ("couldn't load data").
/// 2. A key loss (Keystore invalidated after restore/update/hard kill) made
///    the app generate a fresh key and try to decrypt the existing DB with it
///    (SQLCipher code 26 "file is not a database") — a permanent brick with
///    no recovery. The fix quarantines the unreadable ledger and starts a
///    fresh one instead of looping.
void main() {
  sqfliteFfiInit();

  setUp(() {
    // The SQLCipher plugin is a method channel that does not exist under
    // `flutter test` — ffi stands in (passwords are ignored there, so the
    // wrong-key branch can't be simulated; the schema checks are what matter).
    DatabaseHelper.dbOpenerForTest = (path, {password}) async =>
        databaseFactoryFfi.openDatabase(path);
  });

  tearDown(() {
    DatabaseHelper.dbOpenerForTest = DatabaseHelper.defaultDbOpener;
  });

  Future<Directory> tempDir() => Directory.systemTemp.createTemp('rozz_db_test_');

  // Windows keeps a sqlite file handle briefly after close() — retry cleanup
  // so the temp dir actually goes away.
  Future<void> cleanup(Directory dir) async {
    for (var i = 0; i < 5; i++) {
      try {
        await dir.delete(recursive: true);
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
  }

  test('onUpgrade self-heals a schema-less version-2 DB (the fresh-install brick)', () async {
    final dir = await tempDir();
    final path = '${dir.path}/rozz_database.db';
    try {
      // Reproduce the old bug's artifact exactly: an EMPTY database stamped
      // user_version 2 (the file `_repairZeroVersion` used to create).
      final broken = await databaseFactoryFfi.openDatabase(path);
      await broken.setVersion(2);
      await broken.close();

      // Run the upgrade through sqflite's REAL machinery (it stamps the
      // user_version itself after onUpgrade succeeds — exactly what the app
      // experiences on open).
      final helper = DatabaseHelper();
      final db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 11,
          onUpgrade: (db, from, to) => helper.applyUpgradeForTest(db, from),
        ),
      );
      await db.close();

      final verify = await databaseFactoryFfi.openDatabase(path);
      final tables = await verify.rawQuery(
        "SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name",
      );
      final names = tables.map((t) => t['name']).toSet();
      expect(
        names,
        containsAll([
          'transactions',
          'mab_history',
          'raw_inbox',
          'sender_labels',
          'app_meta',
          'dismissed_subscriptions',
          'merchants',
          'merchant_aliases',
          'statement_uploads',
          'uploaded_rows',
        ]),
      );
      // The v3 migration (DELETE FROM transactions) must have run without
      // throwing — the pre-fix code crashed here with "no such table".
      expect(await verify.getVersion(), 11);
      await verify.close();
    } finally {
      await cleanup(dir);
    }
  });

  test('repairZeroVersion does not create the DB on a fresh install', () async {
    final dir = await tempDir();
    final path = '${dir.path}/rozz_database.db';
    try {
      expect(await File(path).exists(), isFalse);
      final helper = DatabaseHelper();
      await helper.repairZeroVersionForTest(path, 'irrelevant-key');
      // Pre-fix, this call CREATED an empty stamped DB — bricking the app.
      expect(await File(path).exists(), isFalse);
    } finally {
      await cleanup(dir);
    }
  });

  test('isHealthyLedger rejects the schema-less artifact but accepts a real ledger', () async {
    final dir = await tempDir();
    final path = '${dir.path}/rozz_database.db';
    try {
      final helper = DatabaseHelper();

      final artifact = await databaseFactoryFfi.openDatabase(path);
      await artifact.setVersion(2);
      await artifact.close();
      expect(await helper.isHealthyLedgerForTest(path, 'k'), isFalse);

      final good = await databaseFactoryFfi.openDatabase(path);
      await good.execute(
        'CREATE TABLE transactions (id INTEGER PRIMARY KEY, date TEXT NOT NULL)',
      );
      await good.close();
      expect(await helper.isHealthyLedgerForTest(path, 'k'), isTrue);
    } finally {
      await cleanup(dir);
    }
  });

  test('quarantine moves the broken ledger + WAL sidecars aside, keeping one copy', () async {
    final dir = await tempDir();
    final path = '${dir.path}/rozz_database.db';
    try {
      await File(path).writeAsBytes(List.filled(4096, 7));
      await File('$path-wal').writeAsBytes([1, 2, 3]);

      final helper = DatabaseHelper();
      await helper.quarantineBrokenDatabaseForTest(path);

      expect(await File(path).exists(), isFalse);
      expect(await File('$path-wal').exists(), isFalse);
      final leftovers = dir
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split(Platform.pathSeparator).last)
          .toList();
      // The ledger AND its WAL sidecar are both moved aside (kept for
      // forensics), leaving nothing behind for the fresh open.
      expect(leftovers, hasLength(2));
      expect(leftovers.where((f) => !f.endsWith('-wal')), hasLength(1));
      expect(
        leftovers.singleWhere((f) => f.endsWith('-wal')),
        startsWith('rozz_database.db.broken-'),
      );
    } finally {
      await cleanup(dir);
    }
  });
}