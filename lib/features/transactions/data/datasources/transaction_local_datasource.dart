import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';
import 'package:sqflite/sqflite.dart';

abstract class TransactionLocalDatasource {
  Future<void> insertTransaction(TransactionModel transaction);
  Future<List<TransactionModel>> getAllTransactions();
  Future<List<TransactionModel>> getTransactionsByMonth(int month, int year);
  Future<double?> getLastKnownBalance();
  Future<List<TransactionModel>> getUncategorizedTransactions({int limit = 20});
  Future<void> updateCategory(int id, String category);
}

class TransactionLocalDatasourceImpl implements TransactionLocalDatasource {
  final DatabaseHelper _databaseHelper;

  TransactionLocalDatasourceImpl(this._databaseHelper);

  @override
  Future<void> insertTransaction(TransactionModel transaction) async {
    await _databaseHelper.write((db) async {
      if (transaction.id != null) {
        // Upsert: categorization saves the loaded row with its id — a plain insert
        // would hit the PRIMARY KEY conflict and silently drop the category.
        await db.update(
          'transactions',
          transaction.toMap()..remove('id'),
          where: 'id = ?',
          whereArgs: [transaction.id],
        );
      } else {
        await db.insert(
          'transactions',
          transaction.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  @override
  Future<List<TransactionModel>> getAllTransactions() async {
    final List<Map<String, dynamic>> maps = await _databaseHelper.query((db) async {
      return await db.query(
        'transactions',
        orderBy: 'date DESC',
      );
    });
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  @override
  Future<List<TransactionModel>> getTransactionsByMonth(int month, int year) async {
    final List<Map<String, dynamic>> maps = await _databaseHelper.query((db) async {
      return await db.query(
        'transactions',
        where: "strftime('%m', date) = ? AND strftime('%Y', date) = ?",
        whereArgs: [
          month.toString().padLeft(2, '0'),
          year.toString(),
        ],
        orderBy: 'date DESC',
      );
    });
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  @override
  Future<double?> getLastKnownBalance() async {
    // The real current balance is the latest EOD snapshot (recorded from HDFC's
    // daily balance-advice SMS into mab_history), NOT the last transaction's
    // balance_after — that can be weeks stale.
    final eod = await _databaseHelper.query((db) async {
      final maps = await db.query(
        'mab_history',
        columns: ['end_of_day_balance'],
        orderBy: 'date DESC',
        limit: 1,
      );
      if (maps.isEmpty) return null;
      return (maps.first['end_of_day_balance'] as num).toDouble();
    });
    if (eod != null) return eod as double;

    // Fallback: most recent transaction balance
    final List<Map<String, dynamic>> maps = await _databaseHelper.query((db) async {
      return await db.query(
        'transactions',
        columns: ['balance_after'],
        where: 'balance_after IS NOT NULL',
        orderBy: 'date DESC',
        limit: 1,
      );
    });
    if (maps.isNotEmpty) {
      return (maps.first['balance_after'] as num).toDouble();
    }
    return null;
  }

  @override
  Future<List<TransactionModel>> getUncategorizedTransactions({int limit = 20}) async {
    final List<Map<String, dynamic>> maps = await _databaseHelper.query((db) async {
      return await db.query(
        'transactions',
        where: 'category IS NULL AND label_type != ?',
        whereArgs: ['unknown'],
        orderBy: 'date DESC',
        limit: limit,
      );
    });
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  @override
  Future<void> updateCategory(int id, String category) async {
    await _databaseHelper.write((db) async {
      await db.update(
        'transactions',
        {'category': category},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}