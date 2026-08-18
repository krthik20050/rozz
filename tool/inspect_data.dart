// Dev tool: deep-dive into a pulled ROZZ database to answer product questions
// (why subscriptions are missing, what got labeled, SMS parse quality).
//
// Run: dart run tool/inspect_data.dart /c/Users/DELL/rozz_pull.db
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('usage: dart run tool/inspect_data.dart <path-to-db>');
    exit(1);
  }
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    args.first,
    options: OpenDatabaseOptions(readOnly: true),
  );

  final labels = await db.rawQuery('SELECT * FROM sender_labels');
  stdout.writeln('SENDER LABELS (${labels.length}):');
  for (final r in labels) {
    stdout.writeln('  key="${r['sender_key'] ?? r['key']}"  label="${r['label']}"');
  }
  stdout.writeln();

  // Transactions per month, with named vs unnamed counts
  final monthly = await db.rawQuery(
    'SELECT substr(date,1,7) ym, COUNT(*) n, '
    "SUM(CASE WHEN recipient_name IS NULL OR recipient_name='' THEN 1 ELSE 0 END) unnamed "
    'FROM transactions GROUP BY ym ORDER BY ym DESC',
  );
  stdout.writeln('TRANSACTIONS PER MONTH:');
  for (final r in monthly) {
    stdout.writeln('  ${r['ym']}: ${r['n']} total, ${r['unnamed']} unnamed');
  }
  stdout.writeln();

  // Named merchants (grouped), for subscription candidates
  final merchants = await db.rawQuery(
    "SELECT recipient_name, COUNT(*) n, SUM(amount) total "
    "FROM transactions WHERE direction='debit' AND "
    "recipient_name IS NOT NULL AND recipient_name != '' "
    "GROUP BY lower(recipient_name) ORDER BY n DESC LIMIT 30",
  );
  stdout.writeln('DEBIT MERCHANTS (named, by count):');
  for (final r in merchants) {
    stdout.writeln('  "${r['recipient_name']}" x${r['n']} total=${r['total']}');
  }
  stdout.writeln();

  // Any spotify-ish content anywhere (name or raw SMS)
  for (final term in ['spotify', 'max life', 'maxlife', 'lic', 'jio', 'airtel', 'recharge', 'netflix', 'prime', 'hotstar']) {
    final hits = await db.rawQuery(
      "SELECT date, direction, amount, recipient_name, substr(raw_sms,1,160) sms "
      "FROM transactions WHERE lower(coalesce(recipient_name,'')) LIKE ? OR "
      "lower(coalesce(raw_sms,'')) LIKE ? ORDER BY date DESC LIMIT 4",
      ['%$term%', '%$term%'],
    );
    if (hits.isNotEmpty) {
      stdout.writeln('--- "$term" (${hits.length} shown):');
      for (final r in hits) {
        stdout.writeln(
          '  ${r['date']} ${r['direction']} ${r['amount']} name="${r['recipient_name']}"',
        );
        stdout.writeln('    sms: ${r['sms']}');
      }
      stdout.writeln();
    }
  }

  // Credits: what the sender field looks like
  final credits = await db.rawQuery(
    "SELECT date, amount, recipient_name, upi_id, substr(raw_sms,1,140) sms "
    "FROM transactions WHERE direction='credit' ORDER BY date DESC LIMIT 12",
  );
  stdout.writeln('LAST 12 CREDITS:');
  for (final r in credits) {
    stdout.writeln(
      '  ${r['date']} +${r['amount']} name="${r['recipient_name']}" upi="${r['upi_id']}"',
    );
    stdout.writeln('    sms: ${r['sms']}');
  }
  stdout.writeln();

  // Sample of unnamed debits' raw SMS (parse quality)
  final unnamedDebits = await db.rawQuery(
    "SELECT date, amount, substr(raw_sms,1,140) sms "
    "FROM transactions WHERE direction='debit' AND "
    "(recipient_name IS NULL OR recipient_name='') ORDER BY date DESC LIMIT 10",
  );
  stdout.writeln('SAMPLE UNNAMED DEBITS (parse quality):');
  for (final r in unnamedDebits) {
    stdout.writeln('  ${r['date']} ${r['amount']}');
    stdout.writeln('    sms: ${r['sms']}');
  }

  await db.close();
}
