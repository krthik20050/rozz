import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/core/development/desktop_preview.dart';
import 'package:rozz/features/statement_upload/data/datasources/statement_sync_api.dart';
import 'package:rozz/features/statement_upload/data/repositories/statement_sync_repository_impl.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final database = DatabaseHelper();
  final transactions = TransactionLocalDatasourceImpl(database);
  late StatementSyncRepositoryImpl repo;
  setUp(() {
    repo = StatementSyncRepositoryImpl(
      secureStorage: PreviewSecureStorage(),
      api: StatementSyncApi(),
      transactions: transactions,
      databaseHelper: database,
    );
  });
  tearDown(database.close);

  test(
    'local statement import anchors balance and detects re-import duplicates',
    () async {
      const text =
          '01-10-2026 UPI-DR-tpreview@ybl-111111111111-for lunch 120.00 18000.00';
      final first = await repo.importStatementText(text);
      expect(first.inserted, 1);
      expect(first.lastBalance, 18000);
      expect((await transactions.computeBalance()).value, 18000);
      final repeated = await repo.importStatementText(text);
      expect(repeated.inserted, 0);
      expect(repeated.duplicates, 1);
      expect((await transactions.getAllTransactions()).length, 1);
    },
  );

  test(
    'uncertain statement rows remain recoverable without changing balance',
    () async {
      const text = '02-10-2026 Unrecognized description without money';
      final result = await repo.importStatementText(text);
      expect(result.unparsed, 1);
      expect(result.inserted, 0);
      expect((await transactions.computeBalance()).value, isNull);
      final pending = await database.query((db) => db.query('raw_inbox'));
      expect(pending.length, 1);
      await repo.importStatementText(text);
      final repeated = await database.query((db) => db.query('raw_inbox'));
      expect(repeated.length, 1);
    },
  );
}
