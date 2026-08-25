import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/core/services/transaction_sync_service.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';
import 'package:rozz/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:sqflite/sqflite.dart';
import '../../mock_sms.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper db;
  late TransactionRepository repo;
  late TransactionSyncService sync;

  setUp(() async {
    db = DatabaseHelper();
    final datasource = TransactionLocalDatasourceImpl(db);
    repo = TransactionRepositoryImpl(datasource);
    sync = TransactionSyncService(repo, db, SmsParser());
  });

  tearDown(() async {
    await db.close();
  });

  test('backfillIngest parses all 50 fixtures and dedupes on re-ingest', () async {
    var inserted = 0;
    for (final fixture in mockHdfcSms) {
      if (await sync.ingestSms(fixture)) inserted++;
    }
    expect(inserted, 50);

    // Re-ingesting the same messages must not duplicate (upi_ref UNIQUE + dedupe index).
    for (final fixture in mockHdfcSms) {
      await sync.ingestSms(fixture);
    }
    final all = await repo.getAllTransactions();
    expect(all.length, 50);
  });

  test('drainRawInbox parses rows and clears the inbox', () async {
    await db.write((database) async {
      await database.insert('raw_inbox', {'sender': 'HDFCBK', 'body': mockHdfcSms[0]['body'] as String, 'received_at': DateTime.now().millisecondsSinceEpoch});
      await database.insert('raw_inbox', {'sender': 'VM-HDFCBK', 'body': mockHdfcSms[1]['body'] as String, 'received_at': DateTime.now().millisecondsSinceEpoch});
      await database.insert('raw_inbox', {'sender': 'HDFCBK', 'body': 'HDFCBK: Promotional offer text without amount', 'received_at': DateTime.now().millisecondsSinceEpoch});
    });

    final drained = await sync.drainRawInbox();

    expect(drained, 2);
    final all = await repo.getAllTransactions();
    expect(all.length, 2);

    // Unparseable rows (promos/OTPs) are kept for future parser improvements.
    final remaining = await db.query((database) async => database.query('raw_inbox'));
    expect(remaining.length, 1);
  });

  /// Forced DB init sets sqflite_common_ffi as the global factory so
  /// [getDatabasesPath] resolves to a real temp dir, and clears any JSONL state
  /// a previous (possibly failed) test left behind.
  Future<void> resetJsonlFiles() async {
    await db.write((d) async {});
    final dir = await getDatabasesPath();
    for (final name in ['raw_inbox.jsonl', 'raw_inbox.draining.jsonl']) {
      final f = File('$dir/$name');
      if (await f.exists()) await f.delete();
    }
  }

  test('drainPendingSms consumes transactions and drops non-transaction lines', () async {
    await resetJsonlFiles();
    final dir = await getDatabasesPath();
    final file = File('$dir/raw_inbox.jsonl');
    final now = DateTime.now().millisecondsSinceEpoch;
    final promo = jsonEncode({
      'body': 'HDFCBK: Promotional offer text without amount',
      'received_at': now,
    });
    await file.writeAsString([
      jsonEncode({'body': mockHdfcSms[0]['body'], 'received_at': now}),
      jsonEncode({'body': mockHdfcSms[1]['body'], 'received_at': now}),
      promo,
    ].join('\n'), flush: true);

    final drained = await sync.drainPendingSms();

    expect(drained, 2);
    final all = await repo.getAllTransactions();
    expect(all.length, 2);
    // Non-transaction lines are consumed and dropped — re-appending them made
    // the queue grow on every drain. Nothing is left to re-process.
    expect(await file.exists(), isFalse);
    expect(File('$dir/raw_inbox.draining.jsonl').existsSync(), isFalse);
  });

  test('drainPendingSms does not duplicate non-transaction lines across drains', () async {
    await resetJsonlFiles();
    final dir = await getDatabasesPath();
    final file = File('$dir/raw_inbox.jsonl');
    final now = DateTime.now().millisecondsSinceEpoch;
    final promo = jsonEncode({
      'body': 'HDFCBK: Promotional offer text without amount',
      'received_at': now,
    });
    await file.writeAsString(promo, flush: true);

    for (var i = 0; i < 3; i++) {
      await sync.drainPendingSms();
    }

    // The promo is dropped after the first drain and never re-appended, so
    // repeated drains neither grow the file nor spam parse failures.
    expect(await file.exists(), isFalse);
    expect(File('$dir/raw_inbox.draining.jsonl').existsSync(), isFalse);
    expect((await repo.getAllTransactions()).length, 0);
  });

  test('drainPendingSms recovers records joined on one corrupted line', () async {
    await resetJsonlFiles();
    final dir = await getDatabasesPath();
    final file = File('$dir/raw_inbox.jsonl');
    final now = DateTime.now().millisecondsSinceEpoch;
    // A corrupted line: two JSON objects concatenated with no newline. The
    // second is a real credit alert that must be recovered, not lost.
    final joined = jsonEncode({'body': 'HDFCBK: screen time usage 8h 17m', 'received_at': now}) +
        jsonEncode({'body': mockHdfcSms[1]['body'], 'received_at': now});
    await file.writeAsString(joined, flush: true);

    final drained = await sync.drainPendingSms();

    // The credit alert survives; the non-transaction half is dropped.
    expect(drained, 1);
    final all = await repo.getAllTransactions();
    expect(all.length, 1);
    expect(await file.exists(), isFalse);
  });

  test('splitJoinedJson splits only at string-safe boundaries', () {
    final a = jsonEncode({'body': 'x}{y', 'received_at': 1});
    final b = jsonEncode({'body': 'z', 'received_at': 2});
    final parts = TransactionSyncService.splitJoinedJson('$a$b');
    expect(parts.length, 2);
    expect(parts[0], a);
    expect(parts[1], b);

    // A '}{' inside a JSON string value must NOT be split.
    final inside = jsonEncode({'body': 'a}{b', 'received_at': 3});
    expect(TransactionSyncService.splitJoinedJson(inside).length, 1);
  });

  test('drainPendingSms recovers a crashed .draining file then drains the live file', () async {
    await resetJsonlFiles();
    final dir = await getDatabasesPath();
    final file = File('$dir/raw_inbox.jsonl');
    final drainFile = File('$dir/raw_inbox.draining.jsonl');
    final now = DateTime.now().millisecondsSinceEpoch;
    // A previous drain died mid-way, leaving one unconsumed line in .draining.
    await drainFile.writeAsString(
      jsonEncode({'body': mockHdfcSms[0]['body'], 'received_at': now}),
      flush: true,
    );
    // Kotlin appended a fresh message to the live file since then.
    await file.writeAsString(
      jsonEncode({'body': mockHdfcSms[1]['body'], 'received_at': now}),
      flush: true,
    );

    final drained = await sync.drainPendingSms();

    // One drain call consumes BOTH files.
    expect(drained, 2);
    final all = await repo.getAllTransactions();
    expect(all.length, 2);
    expect(drainFile.existsSync(), isFalse);
    expect(file.existsSync(), isFalse);
  });

  test('drainPendingSms consumes the live file and drops a crashed non-transaction leftover', () async {
    await resetJsonlFiles();
    final dir = await getDatabasesPath();
    final file = File('$dir/raw_inbox.jsonl');
    final drainFile = File('$dir/raw_inbox.draining.jsonl');
    final now = DateTime.now().millisecondsSinceEpoch;
    final leftover = jsonEncode({
      'body': 'HDFCBK: Promotional offer text without amount',
      'received_at': now,
    });
    // The crashed drain holds a non-transaction line; the live file was
    // appended to after the original rename.
    await drainFile.writeAsString(leftover, flush: true);
    await file.writeAsString(
      jsonEncode({'body': mockHdfcSms[0]['body'], 'received_at': now}),
      flush: true,
    );

    final drained = await sync.drainPendingSms();

    // The post-rename live transaction is consumed; the crashed non-transaction
    // leftover is dropped (it is not a transaction and would only duplicate).
    expect(drained, 1);
    final all = await repo.getAllTransactions();
    expect(all.length, 1);
    expect(await file.exists(), isFalse);
    expect(drainFile.existsSync(), isFalse);
  });
}