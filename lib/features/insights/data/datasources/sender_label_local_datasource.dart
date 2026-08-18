import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/features/insights/data/models/sender_label_model.dart';
import 'package:sqflite/sqflite.dart';

abstract class SenderLabelLocalDatasource {
  Future<List<SenderLabelModel>> getAll();
  Future<SenderLabelModel?> getByKey(String key);
  Future<void> upsert(SenderLabelModel label);
  Future<void> delete(String key);
}

class SenderLabelLocalDatasourceImpl implements SenderLabelLocalDatasource {
  final DatabaseHelper _databaseHelper;

  SenderLabelLocalDatasourceImpl(this._databaseHelper);

  @override
  Future<List<SenderLabelModel>> getAll() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sender_labels',
      orderBy: 'label COLLATE NOCASE ASC',
    );
    return List.generate(maps.length, (i) => SenderLabelModel.fromMap(maps[i]));
  }

  @override
  Future<SenderLabelModel?> getByKey(String key) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sender_labels',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SenderLabelModel.fromMap(maps.first);
  }

  @override
  Future<void> upsert(SenderLabelModel label) async {
    await _databaseHelper.write((db) async {
      await db.insert(
        'sender_labels',
        label.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> delete(String key) async {
    await _databaseHelper.write((db) async {
      await db.delete('sender_labels', where: 'key = ?', whereArgs: [key]);
    });
  }
}
