// Dev tool: verify the v5 migration state of a pulled DB.
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('usage: dart run tool/check_migration.dart <path-to-db>');
    exit(1);
  }
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    args.first,
    options: OpenDatabaseOptions(readOnly: true),
  );
  final version = await db.rawQuery('PRAGMA user_version');
  stdout.writeln('user_version: ${version.first.values.first}');

  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table'",
  );
  final names = tables.map((t) => t['name']).toList();
  stdout.writeln('tables: ${names.join(', ')}');
  if (names.contains('app_meta')) {
    final meta = await db.rawQuery('SELECT * FROM app_meta');
    stdout.writeln('app_meta: ${meta.map((r) => '${r['key']}=${r['value']}').join(', ')}');
  }

  final broken = await db.rawQuery(
    "SELECT COUNT(*) c FROM transactions WHERE recipient_name LIKE '%\n%'",
  );
  stdout.writeln('multi-line recipient rows: ${broken.first['c']}');

  final spotify = await db.rawQuery(
    "SELECT recipient_name FROM transactions WHERE raw_sms LIKE '%SPOTIFY%' LIMIT 3",
  );
  stdout.writeln('spotify rows: ${spotify.map((r) => '["${r['recipient_name']}"]').join(', ')}');

  await db.close();
}
