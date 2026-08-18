// Dev tool: find recurring income, check subscription detection, and list
// MAB record dates on a pulled DB.
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('usage: dart run tool/analyze_income.dart <path-to-db>');
    exit(1);
  }
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    args.first,
    options: OpenDatabaseOptions(readOnly: true),
  );

  // 1. All credit senders grouped by month, to spot recurring income.
  final credits = await db.rawQuery(
    "SELECT recipient_name, substr(date,1,7) ym, COUNT(*) n, "
    'ROUND(SUM(amount)) total FROM transactions WHERE direction=\'credit\' '
    'GROUP BY recipient_name, substr(date,1,7) ORDER BY recipient_name, ym',
  );
  stdout.writeln('=== CREDIT SENDERS BY MONTH ===');
  final bySender = <String, Map<String, double>>{};
  for (final r in credits) {
    final name = (r['recipient_name'] as String?) ?? '(null)';
    bySender.putIfAbsent(name, () => {});
    bySender[name]![r['ym'] as String] = (r['total'] as num).toDouble();
  }
  // Print senders that appear in 2+ months (recurring candidates).
  bySender.forEach((sender, months) {
    if (months.length >= 2) {
      final amounts = months.entries.map((e) => '${e.key}=₹${e.value.round()}').join(', ');
      stdout.writeln('  "$sender": $amounts');
    }
  });

  // 2. Subscription candidates: same merchant debit in 3+ months.
  final debits = await db.rawQuery(
    "SELECT recipient_name, substr(date,1,7) ym, COUNT(*) n, "
    'ROUND(SUM(amount)) total FROM transactions WHERE direction=\'debit\' '
    'GROUP BY recipient_name, substr(date,1,7) ORDER BY recipient_name, ym',
  );
  stdout.writeln('\n=== DEBIT MERCHANTS IN 3+ MONTHS ===');
  final byMerchant = <String, Map<String, double>>{};
  for (final r in debits) {
    final name = (r['recipient_name'] as String?) ?? '(null)';
    byMerchant.putIfAbsent(name, () => {});
    byMerchant[name]![r['ym'] as String] = (r['total'] as num).toDouble();
  }
  byMerchant.forEach((merchant, months) {
    if (months.length >= 3) {
      final amounts = months.entries.map((e) => '${e.key}=₹${e.value.round()}').join(', ');
      stdout.writeln('  "$merchant": $amounts');
    }
  });

  // 3. Spotify rows specifically.
  final spotify = await db.rawQuery(
    "SELECT substr(date,1,7) ym, amount, recipient_name FROM transactions "
    "WHERE recipient_name LIKE '%SPOTIFY%' ORDER BY date",
  );
  stdout.writeln('\n=== SPOTIFY ROWS ===');
  for (final r in spotify) {
    stdout.writeln('  ${r['ym']} ₹${r['amount']} ("${r['recipient_name']}")');
  }

  // 4. Sender labels.
  final labels = await db.rawQuery('SELECT * FROM sender_labels');
  stdout.writeln('\n=== SENDER LABELS ===');
  for (final r in labels) {
    stdout.writeln('  "${r['key']}" -> "${r['label']}"');
  }

  // 5. MAB record dates (to spot weird/future dates like "26 AUG").
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table'",
  );
  stdout.writeln('\n=== TABLES ===');
  for (final t in tables) {
    stdout.writeln('  ${t['name']}');
  }
  try {
    final mab = await db.rawQuery('SELECT * FROM mab_records ORDER BY date LIMIT 40');
    stdout.writeln('\n=== MAB RECORDS (${mab.length}) ===');
    for (final r in mab) {
      stdout.writeln('  ${r['date']} = ${r['end_of_day_balance']}');
    }
  } catch (e) {
    stdout.writeln('no mab_records table: $e');
  }

  await db.close();
}
