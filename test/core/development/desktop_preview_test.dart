import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/core/development/desktop_preview.dart';
import 'package:rozz/core/services/transaction_sync_service.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/transactions/data/repositories/transaction_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'preview fixtures use real ingest, dedupe, and establish current balance',
    () async {
      final database = DatabaseHelper();
      try {
        final repo = TransactionRepositoryImpl(
          TransactionLocalDatasourceImpl(database),
        );
        final sync = TransactionSyncService(repo, database, SmsParser());
        final now = DateTime(2026, 10, 9, 12);
        final messages = previewMessages(now);
        for (final message in [...messages, ...messages]) {
          expect(await sync.ingestSms(message), isTrue);
        }
        expect((await repo.getAllTransactions()).length, 1);
        final snapshots = await database.query((db) => db.query('mab_history'));
        expect(snapshots.length, 9);
        expect((await repo.computeBalance()).value, 16920);
        await sync.ingestSms({
          'body':
              'Rs.250 credited to HDFC Bank A/c XX4321 from Aarav. Ref PREVIEWCREDIT02',
          'date': now.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
        });
        expect((await repo.computeBalance()).value, 17170);
        // No mobile SQLCipher database or files are used in this test/preview.
      } finally {
        await database.close();
      }
    },
  );
}
