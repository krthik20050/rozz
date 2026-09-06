import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';
import 'package:rozz/features/transactions/domain/usecases/compute_current_balance.dart';
import 'package:sqflite/sqflite.dart';

abstract class TransactionLocalDatasource {
  Future<void> insertTransaction(TransactionModel transaction);
  Future<List<TransactionModel>> getAllTransactions();
  Future<List<TransactionModel>> getTransactionsByMonth(int month, int year);
  Future<double?> getLastKnownBalance();

  /// Running-balance engine: anchor + replay. See [ComputeCurrentBalance].
  Future<ComputedBalance> computeBalance();
  Future<List<TransactionModel>> getUncategorizedTransactions({int limit = 20});
  Future<void> updateCategory(int id, String category);

  /// Half-open date-range read (ISO-8601 TEXT sorts lexicographically) — the
  /// statement linker fetches its matching window with this.
  Future<List<TransactionModel>> getTransactionsBetween(
    String startIsoDate,
    String endIsoDate,
  );

  /// Debits that have no merchant identity yet — the AI-cluster backfill pass
  /// re-probes their aliases after a statement upload learns new merchants.
  Future<List<TransactionModel>> getUnlinkedDebits({int limit = 400});

  /// Stamp a statement-linked row with its merchant (optionally adopting the
  /// merchant's default narration the same write).
  Future<void> updateMerchantKey(
    int id,
    String merchantKey, {
    String? userNarration,
  });

  /// Hard delete (undo-upload path). Never used outside the statement flow.
  Future<void> deleteTransactions(List<int> ids);
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
    // ISO-8601 TEXT sorts lexicographically, so a half-open range over the
    // month boundary is sargable (index-able) — strftime would force a full
    // scan of every transaction on every month load.
    final monthStart = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
    final next = DateTime.utc(year, month + 1, 1);
    final nextMonthStart =
        '${next.year.toString().padLeft(4, '0')}-${next.month.toString().padLeft(2, '0')}-01';
    final List<Map<String, dynamic>> maps = await _databaseHelper.query((db) async {
      return await db.query(
        'transactions',
        where: 'date >= ? AND date < ?',
        whereArgs: [monthStart, nextMonthStart],
        orderBy: 'date DESC',
      );
    });
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  @override
  Future<double?> getLastKnownBalance() async {
    return (await computeBalance()).value;
  }

  /// The real current balance, computed by the running-balance engine:
  /// anchor on the newest bank-reported balance (a transaction SMS with
  /// "Avl bal ₹X" → transactions.balance_after, or HDFC's daily balance
  /// advice → mab_history.end_of_day_balance), then replay every ledger
  /// transaction AFTER that anchor — each one is a real bank-reported
  /// credit/debit, so the number stays live as new SMS land.
  ///
  /// With no bank-reported balance anywhere, returns
  /// [BalanceConfidence.unknown] — callers must not invent a number.
  @override
  Future<ComputedBalance> computeBalance() async {
    // Both anchor sources and the ledger are read in one go; the engine
    // picks the newest anchor and replays forward from it.
    final results = await Future.wait([
      _databaseHelper.query((db) async {
        return await db.query(
          'transactions',
          columns: ['date', 'amount', 'direction'],
          orderBy: 'date ASC',
        );
      }),
      _databaseHelper.query((db) async {
        return await db.query(
          'transactions',
          columns: ['date', 'balance_after'],
          where: 'balance_after IS NOT NULL',
          orderBy: 'date DESC',
          limit: 1,
        );
      }),
      _databaseHelper.query((db) async {
        return await db.query(
          'mab_history',
          columns: ['date', 'end_of_day_balance'],
          orderBy: 'date DESC',
          limit: 1,
        );
      }),
    ]);
    final txRows = results[0];
    final anchorRows = [
      ...results[1],
      ...results[2],
    ];

    final anchors = anchorRows
        .map((row) => BalanceAnchor(
              date: row['date'] as String,
              balance:
                  ((row['balance_after'] ?? row['end_of_day_balance']) as num)
                      .toDouble(),
            ))
        .toList();

    final transactions = txRows
        .map((row) => TransactionModel(
              date: row['date'] as String,
              amount: (row['amount'] as num).toDouble(),
              direction: row['direction'] as String,
              labelType: 'unknown',
              source: 'sms',
            ))
        .toList();

    return const ComputeCurrentBalance().compute(
      transactions: transactions,
      anchors: anchors,
    );
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

  @override
  Future<List<TransactionModel>> getTransactionsBetween(
    String startIsoDate,
    String endIsoDate,
  ) async {
    final List<Map<String, dynamic>> maps =
        await _databaseHelper.query((db) async {
      return await db.query(
        'transactions',
        where: 'date >= ? AND date < ?',
        whereArgs: [startIsoDate, endIsoDate],
        orderBy: 'date ASC',
      );
    });
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  @override
  Future<List<TransactionModel>> getUnlinkedDebits({int limit = 400}) async {
    final List<Map<String, dynamic>> maps =
        await _databaseHelper.query((db) async {
      return await db.query(
        'transactions',
        where: "direction = 'debit' AND merchant_key IS NULL",
        orderBy: 'date DESC',
        limit: limit,
      );
    });
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  @override
  Future<void> updateMerchantKey(
    int id,
    String merchantKey, {
    String? userNarration,
  }) async {
    await _databaseHelper.write((db) async {
      final values = <String, Object?>{'merchant_key': merchantKey};
      if (userNarration != null) values['user_narration'] = userNarration;
      await db.update(
        'transactions',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  @override
  Future<void> deleteTransactions(List<int> ids) async {
    if (ids.isEmpty) return;
    await _databaseHelper.write((db) async {
      await db.delete(
        'transactions',
        where: 'id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
      );
    });
  }
}