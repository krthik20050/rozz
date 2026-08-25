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

  test('getLastKnownBalance: same-day transaction balance_after wins over EOD-task snapshot', () async {
    // The same-day mab_history row is the EOD background task's mid-day
    // estimate — a same-day transaction's balance_after is fresher evidence.
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
    expect(await datasource.getLastKnownBalance(), 250.0);
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

  test('getTransactionsByMonth: range predicate returns only that month', () async {
    for (final tx in [
      TransactionModel(
        date: '2026-07-31T23:59:59.000',
        amount: 1.0,
        direction: 'debit',
        labelType: 'upi_debit',
        source: 'sms',
      ),
      TransactionModel(
        date: '2026-08-01T00:00:00.000',
        amount: 2.0,
        direction: 'debit',
        labelType: 'upi_debit',
        source: 'sms',
      ),
      TransactionModel(
        date: '2026-08-15T12:00:00.000',
        amount: 3.0,
        direction: 'debit',
        labelType: 'upi_debit',
        source: 'sms',
      ),
      TransactionModel(
        date: '2026-08-31T23:59:59.000',
        amount: 4.0,
        direction: 'debit',
        labelType: 'upi_debit',
        source: 'sms',
      ),
      TransactionModel(
        date: '2026-09-01T00:00:00.000',
        amount: 5.0,
        direction: 'debit',
        labelType: 'upi_debit',
        source: 'sms',
      ),
    ]) {
      await datasource.insertTransaction(tx);
    }

    final august = await datasource.getTransactionsByMonth(8, 2026);
    expect(august.length, 3);
    expect(august.map((t) => t.amount).toSet(), {2.0, 3.0, 4.0});
    // DESC order: newest first.
    expect(august.first.amount, 4.0);

    // December rolls into the next year correctly.
    for (final tx in [
      TransactionModel(
        date: '2026-12-31T12:00:00.000',
        amount: 6.0,
        direction: 'debit',
        labelType: 'upi_debit',
        source: 'sms',
      ),
      TransactionModel(
        date: '2027-01-01T00:00:00.000',
        amount: 7.0,
        direction: 'debit',
        labelType: 'upi_debit',
        source: 'sms',
      ),
    ]) {
      await datasource.insertTransaction(tx);
    }
    final december = await datasource.getTransactionsByMonth(12, 2026);
    expect(december.length, 1);
    expect(december.first.amount, 6.0);
  });
}
