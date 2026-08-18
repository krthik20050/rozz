// Dev tool: dump real credit SMS samples.
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('usage: dart run tool/inspect_credits.dart <path-to-db>');
    exit(1);
  }
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    args.first,
    options: OpenDatabaseOptions(readOnly: true),
  );
  final rows = await db.rawQuery(
    "SELECT date, amount, recipient_name, upi_id, substr(raw_sms,1,180) sms "
    "FROM transactions WHERE direction='credit' ORDER BY date DESC LIMIT 15",
  );
  for (final r in rows) {
    stdout.writeln('--- ${r['date']} +${r['amount']}');
    stdout.writeln('    name="${r['recipient_name']}" upi="${r['upi_id']}"');
    stdout.writeln('    sms: ${r['sms']}');
  }
  // Also: how many distinct raw recipient strings for credits?
  final distinct = await db.rawQuery(
    "SELECT recipient_name, COUNT(*) n FROM transactions WHERE direction='credit' "
    "GROUP BY recipient_name ORDER BY n DESC LIMIT 15",
  );
  stdout.writeln('\nCREDIT RECIPIENT NAMES (by count):');
  for (final r in distinct) {
    stdout.writeln('  "${r['recipient_name']}" x${r['n']}');
  }
  await db.close();
}
