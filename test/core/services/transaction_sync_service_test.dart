import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/core/services/transaction_sync_service.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';
import 'package:rozz/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
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
}