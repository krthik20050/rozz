import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper databaseHelper;
  late TransactionLocalDatasourceImpl datasource;

  setUp(() async {
    databaseHelper = DatabaseHelper();
    datasource = TransactionLocalDatasourceImpl(databaseHelper);
    final db = await databaseHelper.database;
    await db.delete('transactions');
  });

  test('should ignore transactions with same upi_ref_number', () async {
    final tx = TransactionModel(
      date: DateTime.now().toUtc().toIso8601String(),
      amount: 100.0,
      direction: 'debit',
      labelType: 'upi_debit',
      upiRefNumber: 'REF123',
      source: 'sms',
    );

    await datasource.insertTransaction(tx);
    await datasource.insertTransaction(tx); // Should be ignored

    final all = await datasource.getAllTransactions();
    expect(all.length, 1);
  });
}
