import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/features/mab/data/datasources/mab_local_datasource.dart';
import 'package:rozz/features/mab/data/models/mab_record_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper databaseHelper;
  late MabLocalDatasourceImpl datasource;

  setUp(() async {
    databaseHelper = DatabaseHelper();
    await databaseHelper.close(); // Ensure previous connections are closed
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rozz.db');
    if (await databaseFactory.databaseExists(path)) {
      await databaseFactory.deleteDatabase(path);
    }
    
    datasource = MabLocalDatasourceImpl(databaseHelper);
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  test('should insert and replace records with same date', () async {
    final record1 = MabRecordModel(
      date: '2026-03-12',
      endOfDayBalance: 5000.0,
      month: 3,
      year: 2026,
    );
    final record2 = MabRecordModel(
      date: '2026-03-12',
      endOfDayBalance: 6000.0,
      month: 3,
      year: 2026,
    );

    await datasource.insertEodBalance(record1);
    await datasource.insertEodBalance(record2);

    final all = await datasource.getMonthRecords(3, 2026);
    expect(all.length, 1);
    expect(all.first.endOfDayBalance, 6000.0);
  });

  test('should return records in ascending order by date', () async {
    final record1 = MabRecordModel(
      date: '2026-03-15',
      endOfDayBalance: 5000.0,
      month: 3,
      year: 2026,
    );
    final record2 = MabRecordModel(
      date: '2026-03-12',
      endOfDayBalance: 6000.0,
      month: 3,
      year: 2026,
    );

    await datasource.insertEodBalance(record1);
    await datasource.insertEodBalance(record2);

    final all = await datasource.getMonthRecords(3, 2026);
    expect(all.length, 2);
    expect(all.first.date, '2026-03-12');
    expect(all.last.date, '2026-03-15');
  });
}
