import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/features/merchants/domain/entities/merchant.dart';
import 'package:sqflite/sqflite.dart';

/// Storage for the merchants + merchant_aliases tables.
///
/// Every read/write has an optional [DatabaseExecutor] first argument: the
/// ingest and statement flows run inside one big DB transaction, so their
/// alias resolution and profile reads must join that transaction instead of
/// going through the WriteQueue (which would deadlock behind it).
abstract class MerchantLocalDatasource {
  Future<Merchant?> getMerchant(String merchantKey);

  /// Resolve raw alias keys to merchant keys, in the given order.
  Future<List<MerchantAliasRow>> lookupAliases(List<String> aliasKeys);

  /// Best merchant for [aliasKeys] (first key in order that has an alias row),
  /// or null when none resolve.
  Future<Merchant?> resolveByAliases(List<String> aliasKeys);

  Future<void> upsertMerchant(MerchantDraft draft);

  Future<void> addAlias(String aliasKey, String merchantKey, String kind);

  /// Maintains tx_count / last_seen so derived data never drifts.
  Future<void> recountMerchant(String merchantKey);

  /// All merchants with debit totals, for the manage screen. Sorted by total
  /// amount descending. Optionally limited to merchants with transactions.
  Future<List<Merchant>> getAllMerchants();

  Future<DescriptionApply> applyDescription({
    required String merchantKey,
    required String description,
    bool merchantWide = false,
    int? triggerTxId,
  });

  Future<DescriptionApply> clearDescription({
    required String merchantKey,
    String? currentDescription,
  });

  // --- executor-aware core (used inside a caller-owned transaction) ---

  Future<Merchant?> getMerchantWithDb(DatabaseExecutor db, String merchantKey);

  Future<List<MerchantAliasRow>> lookupAliasesWithDb(
    DatabaseExecutor db,
    List<String> aliasKeys,
  );

  Future<Merchant?> resolveByAliasesWithDb(
    DatabaseExecutor db,
    List<String> aliasKeys,
  );

  Future<void> upsertMerchantWithDb(DatabaseExecutor db, MerchantDraft draft);

  Future<void> addAliasWithDb(
    DatabaseExecutor db,
    String aliasKey,
    String merchantKey,
    String kind,
  );

  Future<void> recountMerchantWithDb(DatabaseExecutor db, String merchantKey);

  Future<void> setConflictWithDb(DatabaseExecutor db, String merchantKey, bool conflict);

  /// Applies [description] to a merchant's payments. One atomic write across
  /// `merchants` + `transactions`; never clobbers a different purpose.
  ///
  /// [merchantWide] (manage-merchants edit): every linked payment adopts it,
  /// the profile default is set and any conflict is cleared.
  ///
  /// Transaction-level describe ([triggerTxId] set): the described payment
  /// adopts it, PLUS payments of the same merchant with no narration of their
  /// own (or only the old profile default). If the merchant already had a
  /// DIFFERENT profile description, only the trigger row changes and the
  /// merchant is marked conflicted — the UI asks instead of guessing.
  Future<DescriptionApply> applyDescriptionWithDb(
    DatabaseExecutor db, {
    required String merchantKey,
    required String description,
    bool merchantWide = false,
    int? triggerTxId,
  });

  /// Removes the merchant's profile description and strips the *propagated*
  /// copies (rows equal to [currentDescription]); other narrations stay.
  Future<DescriptionApply> clearDescriptionWithDb(
    DatabaseExecutor db, {
    required String merchantKey,
    String? currentDescription,
  });
}

/// What a description write did — drives the UI toast/chips.
class DescriptionApply {
  /// Rows whose `user_narration` changed.
  final int rowsChanged;

  /// True when the write created/exposed a merchant conflict (two different
  /// descriptions from the user) instead of a clean propagation.
  final bool conflict;

  const DescriptionApply({required this.rowsChanged, this.conflict = false});
}

class MerchantAliasRow {
  final String aliasKey;
  final String merchantKey;

  const MerchantAliasRow(this.aliasKey, this.merchantKey);
}

/// Fields to create-or-refresh a merchant row.
class MerchantDraft {
  final String merchantKey;
  final String canonicalName;
  final String source;

  const MerchantDraft({
    required this.merchantKey,
    required this.canonicalName,
    required this.source,
  });
}

class MerchantLocalDatasourceImpl implements MerchantLocalDatasource {
  final DatabaseHelper _helper;

  MerchantLocalDatasourceImpl(this._helper);

  @override
  Future<Merchant?> getMerchant(String merchantKey) async {
    final result = await _helper.query((db) => getMerchantWithDb(db, merchantKey));
    return result as Merchant?;
  }

  @override
  Future<Merchant?> getMerchantWithDb(DatabaseExecutor db, String merchantKey) async {
    final maps = await db.query(
      'merchants',
      where: 'merchant_key = ?',
      whereArgs: [merchantKey],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _merchantFromRow(maps.first, txCount: 0, totalAmount: 0);
  }

  @override
  Future<List<MerchantAliasRow>> lookupAliases(List<String> aliasKeys) async {
    final result = await _helper.query((db) => lookupAliasesWithDb(db, aliasKeys));
    return (result as List).cast<MerchantAliasRow>();
  }

  @override
  Future<Merchant?> resolveByAliases(List<String> aliasKeys) async {
    final result = await _helper.query((db) => resolveByAliasesWithDb(db, aliasKeys));
    return result as Merchant?;
  }

  /// Chooses the alias that appears earliest in [aliasKeys] (callers order
  /// candidates by confidence) and returns its merchant row.
  static MerchantAliasRow? bestAlias(
    List<String> aliasKeys,
    List<MerchantAliasRow> rows,
  ) {
    for (final key in aliasKeys) {
      for (final row in rows) {
        if (row.aliasKey == key) return row;
      }
    }
    return null;
  }

  @override
  Future<List<MerchantAliasRow>> lookupAliasesWithDb(
    DatabaseExecutor db,
    List<String> aliasKeys,
  ) async {
    if (aliasKeys.isEmpty) return const [];
    final maps = await db.query(
      'merchant_aliases',
      columns: ['alias_key', 'merchant_key'],
      where: 'alias_key IN (${List.filled(aliasKeys.length, '?').join(',')})',
      whereArgs: aliasKeys,
    );
    return maps
        .map((m) => MerchantAliasRow(m['alias_key'] as String, m['merchant_key'] as String))
        .toList();
  }

  @override
  Future<Merchant?> resolveByAliasesWithDb(
    DatabaseExecutor db,
    List<String> aliasKeys,
  ) async {
    if (aliasKeys.isEmpty) return null;
    final rows = await lookupAliasesWithDb(db, aliasKeys);
    final best = bestAlias(aliasKeys, rows);
    if (best == null) return null;
    return getMerchantWithDb(db, best.merchantKey);
  }

  @override
  Future<void> upsertMerchant(MerchantDraft draft) async {
    await _helper.write((db) => upsertMerchantWithDb(db, draft));
  }

  @override
  Future<void> upsertMerchantWithDb(DatabaseExecutor db, MerchantDraft draft) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      'merchants',
      {
        'merchant_key': draft.merchantKey,
        'canonical_name': draft.canonicalName,
        'source': draft.source,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    // Refresh the display name + source when the row already existed.
    await db.update(
      'merchants',
      {'canonical_name': draft.canonicalName, 'source': draft.source, 'updated_at': now},
      where: 'merchant_key = ?',
      whereArgs: [draft.merchantKey],
    );
  }

  @override
  Future<void> addAlias(String aliasKey, String merchantKey, String kind) async {
    await _helper.write((db) => addAliasWithDb(db, aliasKey, merchantKey, kind));
  }

  @override
  Future<void> addAliasWithDb(
    DatabaseExecutor db,
    String aliasKey,
    String merchantKey,
    String kind,
  ) async {
    await db.insert(
      'merchant_aliases',
      {
        'alias_key': aliasKey,
        'merchant_key': merchantKey,
        'kind': kind,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<void> recountMerchant(String merchantKey) async {
    await _helper.write((db) => recountMerchantWithDb(db, merchantKey));
  }

  @override
  Future<void> recountMerchantWithDb(DatabaseExecutor db, String merchantKey) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawUpdate(
      'UPDATE merchants SET '
      "tx_count = (SELECT COUNT(*) FROM transactions t WHERE t.merchant_key = merchants.merchant_key AND t.direction = 'debit'), "
      "last_seen = (SELECT MAX(t.date) FROM transactions t WHERE t.merchant_key = merchants.merchant_key), "
      'updated_at = ? WHERE merchant_key = ?',
      [now, merchantKey],
    );
  }

  @override
  Future<void> setConflictWithDb(DatabaseExecutor db, String merchantKey, bool conflict) async {
    await db.update(
      'merchants',
      {'conflict': conflict ? 1 : 0, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'merchant_key = ?',
      whereArgs: [merchantKey],
    );
  }

  @override
  Future<List<Merchant>> getAllMerchants() async {
    final maps = (await _helper.query((db) async {
      return db.rawQuery('''
        SELECT m.merchant_key,
               m.canonical_name,
               m.category,
               m.description,
               m.source,
               m.conflict,
               m.last_seen,
               COALESCE(SUM(CASE WHEN t.direction = 'debit' THEN t.amount ELSE 0 END), 0) AS total_amount,
               COUNT(t.id) AS tx_count
        FROM merchants m
        LEFT JOIN transactions t ON t.merchant_key = m.merchant_key
        GROUP BY m.merchant_key
        ORDER BY total_amount DESC
      ''');
    })) as List<Map<String, dynamic>>;
    return maps.map(_merchantFromSummaryRow).toList();
  }

  Merchant _merchantFromSummaryRow(Map<String, dynamic> m) {
    final txCount = (m['tx_count'] as num).toInt();
    final total = (m['total_amount'] as num).toDouble();
    return _merchantFromRow(m, txCount: txCount, totalAmount: total);
  }

  Merchant _merchantFromRow(
    Map<String, dynamic> m, {
    required int txCount,
    required double totalAmount,
  }) {
    return Merchant(
      merchantKey: m['merchant_key'] as String,
      canonicalName: m['canonical_name'] as String,
      category: m['category'] as String?,
      description: m['description'] as String?,
      source: m['source'] as String,
      conflict: (m['conflict'] as num? ?? 0) == 1,
      txCount: txCount,
      totalAmount: totalAmount,
      lastSeen: m['last_seen'] as String?,
    );
  }

  @override
  Future<DescriptionApply> applyDescription({
    required String merchantKey,
    required String description,
    bool merchantWide = false,
    int? triggerTxId,
  }) async {
    final result = await _helper.write((db) => applyDescriptionWithDb(
          db,
          merchantKey: merchantKey,
          description: description,
          merchantWide: merchantWide,
          triggerTxId: triggerTxId,
        ));
    return result as DescriptionApply;
  }

  @override
  Future<DescriptionApply> clearDescription({
    required String merchantKey,
    String? currentDescription,
  }) async {
    final result = await _helper.write((db) => clearDescriptionWithDb(
          db,
          merchantKey: merchantKey,
          currentDescription: currentDescription,
        ));
    return result as DescriptionApply;
  }

  @override
  Future<DescriptionApply> applyDescriptionWithDb(
    DatabaseExecutor db, {
    required String merchantKey,
    required String description,
    bool merchantWide = false,
    int? triggerTxId,
  }) async {
    final trimmed = description.trim();
    if (trimmed.isEmpty) {
      return const DescriptionApply(rowsChanged: 0);
    }
    final existing = await getMerchantWithDb(db, merchantKey);
    final profileDescription = existing?.description;
    final now = DateTime.now().toUtc().toIso8601String();
    var rows = 0;
    var conflict = false;

    // Manage-merchants edit: deliberate, whole-merchant rename.
    if (merchantWide) {
      final update = await db.update(
        'transactions',
        {'user_narration': trimmed},
        where: 'merchant_key = ?',
        whereArgs: [merchantKey],
      );
      rows = update;
      // A deliberate rename resolves the conflict — one word wins everywhere.
      await setConflictWithDb(db, merchantKey, false);
    } else if (profileDescription != null &&
        profileDescription != trimmed &&
        triggerTxId != null) {
      // A payment described differently from the merchant's default: this row
      // only, and mark the conflict so future auto-apply stops guessing.
      await db.update(
        'transactions',
        {'user_narration': trimmed},
        where: 'id = ?',
        whereArgs: [triggerTxId],
      );
      rows = 1;
      conflict = true;
      await setConflictWithDb(db, merchantKey, true);
    } else {
      // First description / same-as-default edit / no conflicting default:
      // adopt on rows with no narration of their own or only the old default.
      final args = <Object>[merchantKey];
      var where = 'merchant_key = ? AND (user_narration IS NULL';
      if (profileDescription != null && profileDescription != trimmed) {
        // Rows carrying the OLD default were propagated — they may follow the
        // new word too, while rows with their own narration stay untouched.
        where += ' OR user_narration = ?';
        args.add(profileDescription);
      }
      where += ')';
      final update = await db.update('transactions', {'user_narration': trimmed},
          where: where, whereArgs: args);
      rows = update;
      // The trigger row may carry an older manual note and be excluded above.
      if (triggerTxId != null && rows == 0) {
        await db.update(
          'transactions',
          {'user_narration': trimmed},
          where: 'id = ?',
          whereArgs: [triggerTxId],
        );
        rows = 1;
      }
    }

    await db.update(
      'merchants',
      {'description': trimmed, 'source': 'user', 'updated_at': now},
      where: 'merchant_key = ?',
      whereArgs: [merchantKey],
    );
    return DescriptionApply(rowsChanged: rows, conflict: conflict);
  }

  @override
  Future<DescriptionApply> clearDescriptionWithDb(
    DatabaseExecutor db, {
    required String merchantKey,
    String? currentDescription,
  }) async {
    if (currentDescription == null) {
      return const DescriptionApply(rowsChanged: 0);
    }
    final rows = await db.update(
      'transactions',
      {'user_narration': null},
      where: 'merchant_key = ? AND user_narration = ?',
      whereArgs: [merchantKey, currentDescription],
    );
    await db.update(
      'merchants',
      {
        'description': null,
        'conflict': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'merchant_key = ?',
      whereArgs: [merchantKey],
    );
    return DescriptionApply(rowsChanged: rows);
  }
}
