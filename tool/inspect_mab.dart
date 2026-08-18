// Dev tool: inspect a pulled ROZZ database and compute the MAB forecast
// numbers so we can explain what the MAB screen shows.
//
// Run: dart run tool/inspect_mab.dart /c/Users/DELL/rozz_pull.db
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('usage: dart run tool/inspect_mab.dart <path-to-db>');
    exit(1);
  }
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    args.first,
    options: OpenDatabaseOptions(readOnly: true),
  );

  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table'",
  );
  stdout.writeln('TABLES: ${tables.map((t) => t['name']).join(', ')}');
  stdout.writeln();

  // MAB history for the last two months
  final mabRows = await db.rawQuery(
    'SELECT date, end_of_day_balance FROM mab_history '
    'ORDER BY date DESC LIMIT 40',
  );
  stdout.writeln('MAB HISTORY (last 40):');
  for (final r in mabRows) {
    stdout.writeln('  ${r['date']}  balance=${r['end_of_day_balance']}');
  }
  stdout.writeln();

  // Per-month MAB totals
  final monthly = await db.rawQuery(
    'SELECT substr(date,1,7) AS ym, COUNT(*) AS days, '
    'SUM(end_of_day_balance) AS total FROM mab_history GROUP BY ym ORDER BY ym DESC',
  );
  stdout.writeln('MAB BY MONTH:');
  for (final r in monthly) {
    final total = (r['total'] as num).toDouble();
    stdout.writeln(
      '  ${r['ym']}: ${r['days']} days, total=${total.toStringAsFixed(0)}, '
      'avg=${(total / 31).toStringAsFixed(2)} (÷31) / '
      '${(total / (r['ym'] == '2026-08' ? 15 : 31)).toStringAsFixed(2)} '
      '(÷days-so-far)',
    );
  }
  stdout.writeln();

  // Current balance + recent transactions for context
  final lastTx = await db.rawQuery(
    'SELECT date, direction, amount, recipient_name FROM transactions '
    'ORDER BY date DESC LIMIT 15',
  );
  stdout.writeln('LAST 15 TRANSACTIONS:');
  for (final r in lastTx) {
    stdout.writeln(
      '  ${r['date']}  ${r['direction']}  ${r['amount']}  ${r['recipient_name']}',
    );
  }

  await db.close();
}
