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
    await db.delete('mab_history');
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

  test('getLastKnownBalance: newer transaction balance_after beats older snapshot', () async {
    final db = await databaseHelper.database;
    await db.insert('mab_history', {
      'date': '2026-08-14',
      'end_of_day_balance': 100.0,
      'month': 8,
      'year': 2026,
    });
    await datasource.insertTransaction(TransactionModel(
      date: DateTime.utc(2026, 8, 15).toIso8601String(),
      amount: 50.0,
      direction: 'debit',
      labelType: 'upi_debit',
      balanceAfter: 250.0,
      source: 'sms',
    ));
    expect(await datasource.getLastKnownBalance(), 250.0);
  });

  test('getLastKnownBalance: same-day snapshot wins over transaction balance_after', () async {
    final db = await databaseHelper.database;
    await db.insert('mab_history', {
      'date': '2026-08-15',
      'end_of_day_balance': 300.0,
      'month': 8,
      'year': 2026,
    });
    await datasource.insertTransaction(TransactionModel(
      date: DateTime.utc(2026, 8, 15).toIso8601String(),
      amount: 50.0,
      direction: 'debit',
      labelType: 'upi_debit',
      balanceAfter: 250.0,
      source: 'sms',
    ));
    expect(await datasource.getLastKnownBalance(), 300.0);
  });

  test('getLastKnownBalance: snapshot alone is returned when no balance_after exists', () async {
    final db = await databaseHelper.database;
    await db.insert('mab_history', {
      'date': '2026-08-14',
      'end_of_day_balance': 100.0,
      'month': 8,
      'year': 2026,
    });
    await datasource.insertTransaction(TransactionModel(
      date: DateTime.utc(2026, 8, 15).toIso8601String(),
      amount: 50.0,
      direction: 'debit',
      labelType: 'upi_debit',
      source: 'sms',
    ));
    expect(await datasource.getLastKnownBalance(), 100.0);
  });
}
