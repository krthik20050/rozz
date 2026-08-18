// Dev tool: verify subscription candidates + credit senders on a pulled DB.
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('usage: dart run tool/check_sub.dart <path-to-db>');
    exit(1);
  }
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    args.first,
    options: OpenDatabaseOptions(readOnly: true),
  );
  for (final term in ['SPOTIFY', 'MAX LIFE']) {
    final rows = await db.rawQuery(
      "SELECT substr(date,1,7) ym, amount FROM transactions WHERE recipient_name LIKE ? ORDER BY date",
      ['%$term%'],
    );
    stdout.writeln(
      '$term (${rows.length}): ${rows.map((r) => '${r['ym']}=${r['amount']}').join(', ')}',
    );
  }
  final credits = await db.rawQuery(
    "SELECT recipient_name, COUNT(*) n FROM transactions WHERE direction='credit' "
    'GROUP BY recipient_name ORDER BY n DESC LIMIT 10',
  );
  stdout.writeln('CREDITS NOW:');
  for (final r in credits) {
    stdout.writeln('  "${r['recipient_name']}" x${r['n']}');
  }
  await db.close();
}
