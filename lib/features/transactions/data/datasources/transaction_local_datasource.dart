import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';
import 'package:sqflite/sqflite.dart';

abstract class TransactionLocalDatasource {
  Future<void> insertTransaction(TransactionModel transaction);
  Future<List<TransactionModel>> getAllTransactions();
  Future<List<TransactionModel>> getTransactionsByMonth(int month, int year);
  Future<double?> getLastKnownBalance();
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
}