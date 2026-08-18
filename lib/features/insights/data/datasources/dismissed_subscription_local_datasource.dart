import 'package:rozz/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

/// Local store of subscription merchants the user dismissed as not-a-
/// subscription. Keyed by the same slug ComputeSubscriptions groups on.
abstract class DismissedSubscriptionLocalDatasource {
  Future<Set<String>> getAll();
  Future<void> dismiss(String merchantKey);
  Future<void> restore(String merchantKey);
}

class DismissedSubscriptionLocalDatasourceImpl
    implements DismissedSubscriptionLocalDatasource {
  final DatabaseHelper _databaseHelper;

  DismissedSubscriptionLocalDatasourceImpl(this._databaseHelper);

  @override
  Future<Set<String>> getAll() async {
    final db = await _databaseHelper.database;
    final maps = await db.query('dismissed_subscriptions');
    final keys = {for (final m in maps) (m['merchant_key'] as String?) ?? ''};
    keys.remove('');
    return keys;
  }

  @override
  Future<void> dismiss(String merchantKey) async {
    await _databaseHelper.write((db) async {
      await db.insert(
        'dismissed_subscriptions',
        {'merchant_key': merchantKey},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> restore(String merchantKey) async {
    await _databaseHelper.write((db) async {
      await db.delete(
        'dismissed_subscriptions',
        where: 'merchant_key = ?',
        whereArgs: [merchantKey],
      );
    });
  }
}