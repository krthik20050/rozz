import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';
import 'package:sqflite/sqflite.dart';

abstract class TransactionLocalDatasource {
  Future<void> insertTransaction(TransactionModel transaction);
  Future<void> upsertTransaction(TransactionModel transaction);
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
    final db = await _databaseHelper.database;
    await _databaseHelper.write(() async {
      await db.insert(
        'transactions',
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });
  }

  /// Inserts or replaces a transaction — used when pulling from remote sync
  /// so that remote updates (e.g. newly categorised rows) overwrite stale
  /// local data.
  @override
  Future<void> upsertTransaction(TransactionModel transaction) async {
    final db = await _databaseHelper.database;
    await _databaseHelper.write(() async {
      await db.insert(
        'transactions',
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  @override
  Future<List<TransactionModel>> getTransactionsByMonth(int month, int year) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: "strftime('%m', date) = ? AND strftime('%Y', date) = ?",
      whereArgs: [
        month.toString().padLeft(2, '0'),
        year.toString(),
      ],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  @override
  Future<double?> getLastKnownBalance() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      columns: ['balance_after'],
      where: 'balance_after IS NOT NULL',
      orderBy: 'date DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return (maps.first['balance_after'] as num).toDouble();
    }
    return null;
  }

  @override
  Future<List<TransactionModel>> getUncategorizedTransactions({int limit = 20}) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'category IS NULL AND label_type != ?',
      whereArgs: ['unknown'],
      orderBy: 'date DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  @override
  Future<void> updateCategory(int id, String category) async {
    final db = await _databaseHelper.database;
    await _databaseHelper.write(() async {
      await db.update(
        'transactions',
        {'category': category},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
