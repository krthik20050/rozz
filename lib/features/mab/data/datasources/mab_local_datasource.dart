import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/features/mab/data/models/mab_record_model.dart';
import 'package:sqflite/sqflite.dart';

abstract class MabLocalDatasource {
  Future<void> insertEodBalance(MabRecordModel record);
  Future<List<MabRecordModel>> getMonthRecords(int month, int year);
  Future<List<String>> getMissingDays(int month, int year);
  Future<MabRecordModel?> getLastRecord();
}

class MabLocalDatasourceImpl implements MabLocalDatasource {
  final DatabaseHelper _databaseHelper;

  MabLocalDatasourceImpl(this._databaseHelper);

  @override
  Future<void> insertEodBalance(MabRecordModel record) async {
    final db = await _databaseHelper.database;
    await _databaseHelper.write(() async {
      await db.insert(
        'mab_history',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<List<MabRecordModel>> getMonthRecords(int month, int year) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'mab_history',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) => MabRecordModel.fromMap(maps[i]));
  }

  @override
  Future<List<String>> getMissingDays(int month, int year) async {
    final records = await getMonthRecords(month, year);
    final recordedDates = records.map((r) => r.date).toSet();

    final lastDay = DateTime(year, month + 1, 0).day;
    final today = DateTime.now();
    final maxDay = (today.year == year && today.month == month) ? today.day : lastDay;

    final List<String> missing = [];
    for (int d = 1; d <= maxDay; d++) {
      final date = "$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
      if (!recordedDates.contains(date)) {
        missing.add(date);
      }
    }
    return missing;
  }

  @override
  Future<MabRecordModel?> getLastRecord() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'mab_history',
      orderBy: 'date DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return MabRecordModel.fromMap(maps.first);
    }
    return null;
  }
}
