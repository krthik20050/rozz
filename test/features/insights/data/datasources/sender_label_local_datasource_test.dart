import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/features/insights/data/datasources/sender_label_local_datasource.dart';
import 'package:rozz/features/insights/data/models/sender_label_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper databaseHelper;
  late SenderLabelLocalDatasourceImpl datasource;

  setUp(() async {
    databaseHelper = DatabaseHelper();
    await databaseHelper.close();

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rozz.db');
    if (await databaseFactory.databaseExists(path)) {
      await databaseFactory.deleteDatabase(path);
    }

    datasource = SenderLabelLocalDatasourceImpl(databaseHelper);
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  test('upsert replaces an existing label for the same key', () async {
    await datasource.upsert(const SenderLabelModel(key: 'kk9396', label: 'father'));
    await datasource.upsert(const SenderLabelModel(key: 'kk9396', label: 'dad'));

    final all = await datasource.getAll();
    expect(all.length, 1);
    expect(all.single.label, 'dad');
  });

  test('getByKey returns the label or null', () async {
    await datasource.upsert(const SenderLabelModel(key: 'kk9396', label: 'father'));

    final found = await datasource.getByKey('kk9396');
    expect(found?.label, 'father');

    final missing = await datasource.getByKey('nobody');
    expect(missing, isNull);
  });

  test('delete removes only the requested key', () async {
    await datasource.upsert(const SenderLabelModel(key: 'a', label: 'father'));
    await datasource.upsert(const SenderLabelModel(key: 'b', label: 'mother'));

    await datasource.delete('a');

    final all = await datasource.getAll();
    expect(all.length, 1);
    expect(all.single.key, 'b');
  });
}
