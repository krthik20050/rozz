import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/core/services/transaction_sync_service.dart';
import 'package:rozz/features/merchants/data/datasources/merchant_local_datasource.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper db;
  late TransactionRepository repo;
  late TransactionLocalDatasourceImpl datasource;
  late MerchantLocalDatasourceImpl merchants;
  late TransactionSyncService sync;

  setUp(() async {
    db = DatabaseHelper();
    datasource = TransactionLocalDatasourceImpl(db);
    repo = TransactionRepositoryImpl(datasource);
    merchants = MerchantLocalDatasourceImpl(db);
    sync = TransactionSyncService(repo, db, SmsParser(), merchants);
    final database = await db.database;
    await database.delete('transactions');
    await database.delete('merchants');
    await database.delete('merchant_aliases');
  });

  tearDown(() async {
    await db.close();
  });

  const amazonSms =
      'HDFC Bank: Rs.189.00 debited to AMAZON PAY via UPI from A/c XX4321. '
      'UPI Ref: 987654321012. Avl Bal Rs.3,540.11.';
  const rahulSms =
      'HDFC Bank: Rs.500.00 debited to RAHUL VERMA via UPI from A/c XX4321. '
      'UPI Ref: 123450987654. Avl Bal Rs.3,040.11.';

  test('new SMS debit resolves a described brand merchant and auto-adopts its description', () async {
    await merchants.upsertMerchant(const MerchantDraft(
      merchantKey: 'amazon',
      canonicalName: 'Amazon',
      source: 'user',
    ));
    await merchants.applyDescriptionWithDb(await db.database, merchantKey: 'amazon', description: 'orders');

    expect(await sync.ingestSms({'body': amazonSms}), isTrue);

    final all = await repo.getAllTransactions();
    expect(all.single.merchantKey, 'amazon');
    expect(all.single.userNarration, 'orders');
  });

  test('known brand without a profile still links, without inventing a description', () async {
    expect(await sync.ingestSms({'body': amazonSms}), isTrue);

    final all = await repo.getAllTransactions();
    expect(all.single.merchantKey, 'amazon');
    expect(all.single.userNarration, isNull);
  });

  test('a conflicted merchant never auto-applies its default description', () async {
    await merchants.upsertMerchant(const MerchantDraft(
      merchantKey: 'amazon',
      canonicalName: 'Amazon',
      source: 'user',
    ));
    final database = await db.database;
    await merchants.applyDescriptionWithDb(database, merchantKey: 'amazon', description: 'orders');
    await merchants.setConflictWithDb(database, 'amazon', true);

    expect(await sync.ingestSms({'body': amazonSms}), isTrue);

    final all = await repo.getAllTransactions();
    expect(all.single.merchantKey, 'amazon');
    expect(all.single.userNarration, isNull);
  });

  test('a person payee resolves through its alias rows to the described merchant', () async {
    await merchants.upsertMerchant(const MerchantDraft(
      merchantKey: 'rahulverma',
      canonicalName: 'Rahul Verma',
      source: 'user',
    ));
    final database = await db.database;
    await merchants.applyDescriptionWithDb(database, merchantKey: 'rahulverma', description: 'dinner');
    // Describing seeds the alias store (MerchantBloc._seedAliases): the raw
    // name slug and any VPA local parts now point at the merchant, so a future
    // SMS naming the person differently still links and auto-describes.
    await merchants.addAliasWithDb(database, 'rahulverma', 'rahulverma', 'name');
    await merchants.addAliasWithDb(database, 'rahulv98', 'rahulverma', 'upi_vpa');

    expect(await sync.ingestSms({'body': rahulSms}), isTrue);

    final all = await repo.getAllTransactions();
    expect(all.single.merchantKey, 'rahulverma');
    expect(all.single.userNarration, 'dinner');
  });
}
