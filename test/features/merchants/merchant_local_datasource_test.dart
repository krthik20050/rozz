import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/features/merchants/data/datasources/merchant_local_datasource.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;
  late MerchantLocalDatasourceImpl merchants;
  late TransactionLocalDatasourceImpl txns;

  Future<int> insertDebit({
    required String recipient,
    String date = '2026-08-10T12:00:00.000Z',
    double amount = 100.0,
    String? merchantKey,
    String? narration,
    String? upiId,
    String direction = 'debit',
  }) async {
    final model = TransactionModel(
      date: date,
      amount: amount,
      direction: direction,
      labelType: direction == 'credit' ? 'upi' : 'upi',
      recipientName: recipient,
      upiId: upiId,
      source: 'sms',
      merchantKey: merchantKey,
      userNarration: narration,
    );
    await txns.insertTransaction(model);
    final all = await txns.getAllTransactions();
    return all.firstWhere((t) => t.recipientName == recipient && t.amount == amount).id!;
  }

  setUp(() async {
    dbHelper = DatabaseHelper();
    merchants = MerchantLocalDatasourceImpl(dbHelper);
    txns = TransactionLocalDatasourceImpl(dbHelper);
    final db = await dbHelper.database;
    await db.delete('transactions');
    await db.delete('mab_history');
    await db.delete('merchants');
    await db.delete('merchant_aliases');
    await db.delete('statement_uploads');
    await db.delete('uploaded_rows');
  });

  // Real flows create the merchant row first (MerchantBloc before apply) —
  // the propagation tests mirror that by seeding it.
  Future<void> seedMerchant() async {
    await merchants.upsertMerchant(const MerchantDraft(
      merchantKey: 'rahulverma',
      canonicalName: 'Rahul Verma',
      source: 'user',
    ));
  }

  group('alias resolution', () {
    test('resolveByAliases returns null when nothing links', () async {
      final resolved = await merchants.resolveByAliases(['rahulverma']);
      expect(resolved, isNull);
    });

    test('alias resolves to its merchant with description', () async {
      await merchants.upsertMerchant(const MerchantDraft(
        merchantKey: 'rahulverma',
        canonicalName: 'Rahul Verma',
        source: 'user',
      ));
      await merchants.addAlias('rahulv98', 'rahulverma', 'upi_vpa');
      final resolved = await merchants.resolveByAliases(['rahulv98', 'rahulverma']);
      expect(resolved, isNotNull);
      expect(resolved!.merchantKey, 'rahulverma');
    });
  });

  group('description propagation', () {
    test('first describe propagates to same-merchant rows without their own note', () async {
      final a = await insertDebit(recipient: 'RAHUL VERMA');
      final b = await insertDebit(recipient: 'RAHUL VERMA', amount: 250);
      await txns.updateMerchantKey(a, 'rahulverma');
      await txns.updateMerchantKey(b, 'rahulverma');
      await seedMerchant();

      final apply = await merchants.applyDescription(
        merchantKey: 'rahulverma',
        description: 'dinner',
        triggerTxId: a,
      );

      expect(apply.rowsChanged, 2);
      final all = await txns.getAllTransactions();
      expect(all.every((t) => t.userNarration == 'dinner'), isTrue);
      final merchant = await merchants.getMerchant('rahulverma');
      expect(merchant!.description, 'dinner');
      expect(merchant.conflict, isFalse);
    });

    test('never clobbers a payment described for a different purpose', () async {
      final a = await insertDebit(recipient: 'RAHUL VERMA');
      final b = await insertDebit(recipient: 'RAHUL VERMA', amount: 250, narration: 'rent');
      await txns.updateMerchantKey(a, 'rahulverma');
      await txns.updateMerchantKey(b, 'rahulverma');
      await seedMerchant();

      await merchants.applyDescription(
        merchantKey: 'rahulverma',
        description: 'dinner',
        triggerTxId: a,
      );

      final all = await txns.getAllTransactions();
      expect(all.firstWhere((t) => t.id == a).userNarration, 'dinner');
      expect(all.firstWhere((t) => t.id == b).userNarration, 'rent');
    });

    test('a different purpose on one payment marks the merchant conflicted and changes only that row', () async {
      final a = await insertDebit(recipient: 'RAHUL VERMA');
      final b = await insertDebit(recipient: 'RAHUL VERMA', amount: 250);
      await txns.updateMerchantKey(a, 'rahulverma');
      await txns.updateMerchantKey(b, 'rahulverma');
      await seedMerchant();
      await merchants.applyDescription(
        merchantKey: 'rahulverma',
        description: 'dinner',
        triggerTxId: a,
      );

      final apply = await merchants.applyDescription(
        merchantKey: 'rahulverma',
        description: 'rent',
        triggerTxId: b,
      );

      expect(apply.conflict, isTrue);
      final all = await txns.getAllTransactions();
      expect(all.firstWhere((t) => t.id == a).userNarration, 'dinner');
      expect(all.firstWhere((t) => t.id == b).userNarration, 'rent');
      final merchant = await merchants.getMerchant('rahulverma');
      expect(merchant!.conflict, isTrue);
      // The described row names a purpose; the profile default follows the
      // latest user word so manage-payees still has one canonical answer.
      expect(merchant.description, 'rent');
    });

    test('merchant-wide rename deliberately rewrites every payment and clears conflict', () async {
      final a = await insertDebit(recipient: 'RAHUL VERMA');
      final b = await insertDebit(recipient: 'RAHUL VERMA', amount: 250);
      await txns.updateMerchantKey(a, 'rahulverma');
      await txns.updateMerchantKey(b, 'rahulverma');
      await seedMerchant();
      await merchants.applyDescription(
        merchantKey: 'rahulverma',
        description: 'dinner',
        triggerTxId: a,
      );
      await merchants.applyDescription(
        merchantKey: 'rahulverma',
        description: 'rent',
        triggerTxId: b,
      );

      final apply = await merchants.applyDescription(
        merchantKey: 'rahulverma',
        description: 'rent',
        merchantWide: true,
      );

      // SQLite counts rows whose value actually changed; one already carried
      // 'rent', so the floor is what matters, not an exact 2.
      expect(apply.rowsChanged, greaterThanOrEqualTo(1));
      final all = await txns.getAllTransactions();
      expect(all.every((t) => t.userNarration == 'rent'), isTrue);
      final merchant = await merchants.getMerchant('rahulverma');
      expect(merchant!.conflict, isFalse);
    });

    test('clear removes only propagated copies and the profile default', () async {
      final a = await insertDebit(recipient: 'RAHUL VERMA');
      final b = await insertDebit(recipient: 'RAHUL VERMA', amount: 250, narration: 'rent');
      await txns.updateMerchantKey(a, 'rahulverma');
      await txns.updateMerchantKey(b, 'rahulverma');
      await seedMerchant();
      await merchants.applyDescription(
        merchantKey: 'rahulverma',
        description: 'dinner',
        triggerTxId: a,
      );

      final apply = await merchants.clearDescription(
        merchantKey: 'rahulverma',
        currentDescription: 'dinner',
      );

      expect(apply.rowsChanged, 1);
      final all = await txns.getAllTransactions();
      expect(all.firstWhere((t) => t.id == a).userNarration, isNull);
      expect(all.firstWhere((t) => t.id == b).userNarration, 'rent');
      expect((await merchants.getMerchant('rahulverma'))!.description, isNull);
    });
  });

  group('totals + recount', () {
    test('getAllMerchants sums debit totals only', () async {
      final a = await insertDebit(recipient: 'RAHUL VERMA', amount: 100);
      final b = await insertDebit(recipient: 'RAHUL VERMA', amount: 250);
      await insertDebit(recipient: 'PAPA', amount: 900, direction: 'credit');
      await txns.updateMerchantKey(a, 'rahulverma');
      await txns.updateMerchantKey(b, 'rahulverma');
      await merchants.upsertMerchant(const MerchantDraft(
        merchantKey: 'rahulverma',
        canonicalName: 'Rahul Verma',
        source: 'user',
      ));
      await merchants.recountMerchant('rahulverma');

      final list = await merchants.getAllMerchants();
      expect(list.single.totalAmount, 350);
      expect(list.single.txCount, 2);
    });
  });
}
