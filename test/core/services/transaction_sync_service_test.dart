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

  test('drainPendingSms consumes parseable lines and appends unparseable back to the live file', () async {
    await resetJsonlFiles();
    final dir = await getDatabasesPath();
    final file = File('$dir/raw_inbox.jsonl');
    final now = DateTime.now().millisecondsSinceEpoch;
    final unparseable = jsonEncode({
      'body': 'HDFCBK: Promotional offer text without amount',
      'received_at': now,
    });
    await file.writeAsString([
      jsonEncode({'body': mockHdfcSms[0]['body'], 'received_at': now}),
      jsonEncode({'body': mockHdfcSms[1]['body'], 'received_at': now}),
      unparseable,
    ].join('\n'), flush: true);

    final drained = await sync.drainPendingSms();

    expect(drained, 2);
    final all = await repo.getAllTransactions();
    expect(all.length, 2);
    // Unparseable lines survive in the live file (nothing was truncated away).
    expect((await file.readAsString()).trim(), unparseable);
    expect(File('$dir/raw_inbox.draining.jsonl').existsSync(), isFalse);
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

  test('drainPendingSms never truncates live-file content it did not consume', () async {
    await resetJsonlFiles();
    final dir = await getDatabasesPath();
    final file = File('$dir/raw_inbox.jsonl');
    final drainFile = File('$dir/raw_inbox.draining.jsonl');
    final now = DateTime.now().millisecondsSinceEpoch;
    final leftover = jsonEncode({
      'body': 'HDFCBK: Promotional offer text without amount',
      'received_at': now,
    });
    // The crashed drain holds an unparseable line; the live file was appended
    // to after the original rename and must not be truncated by this drain.
    await drainFile.writeAsString(leftover, flush: true);
    await file.writeAsString(
      jsonEncode({'body': mockHdfcSms[0]['body'], 'received_at': now}),
      flush: true,
    );

    final drained = await sync.drainPendingSms();

    // The post-rename live line is consumed as a fresh file, the crashed
    // leftover survives in the live file — nothing dropped, nothing truncated.
    expect(drained, 1);
    final all = await repo.getAllTransactions();
    expect(all.length, 1);
    expect((await file.readAsString()).trim(), leftover);
    expect(drainFile.existsSync(), isFalse);
  });
}