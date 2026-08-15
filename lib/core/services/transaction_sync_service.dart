import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:sqflite/sqflite.dart';

/// Owns the SMS ingest pipeline: raw_inbox drain (native-written) + inbox backfill.
/// The raw_inbox table is the durable store — Kotlin writes there first, so no
/// SMS is lost when the app process is dead; this service only consumes it.
class TransactionSyncService {
  final TransactionRepository _repository;
  final DatabaseHelper _databaseHelper;
  final SmsParser _parser;
  static const _channel = MethodChannel('com.rozz/sms');

  TransactionSyncService(this._repository, this._databaseHelper, this._parser);

  /// Routes a parsed SMS: balance snapshots go to mab_history (the real current
  /// balance), transactions go to the ledger. Returns true if it was persisted.
  /// Pass [db] when already inside a transaction so the write joins it.
  Future<bool> _persistParsed(
    Map<String, dynamic> parsed,
    String body, {
    DateTime? receivedAt,
    DatabaseExecutor? db,
  }) async {
    if (parsed['label_type'] == 'balance_snapshot') {
      final balance = (parsed['balance'] as num?)?.toDouble();
      if (balance == null) return false;
      final dateStr = parsed['date'] as String? ??
          DateFormat('yyyy-MM-dd').format(receivedAt ?? DateTime.now());
      final row = {
        'date': dateStr,
        'end_of_day_balance': balance,
        'month': int.parse(dateStr.substring(5, 7)),
        'year': int.parse(dateStr.substring(0, 4)),
      };
      if (db != null) {
        await db.insert('mab_history', row, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await _databaseHelper.write((db) async {
          await db.insert('mab_history', row, conflictAlgorithm: ConflictAlgorithm.replace);
        });
      }
      return true;
    }
    if (parsed['amount'] == null) return false;
    if (db != null) {
      // Inside a transaction: insert directly. Going through the repository would
      // enqueue behind the current WriteQueue operation and deadlock.
      await db.insert(
        'transactions',
        TransactionModel.fromSms(parsed, body).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await _repository.saveTransaction(TransactionModel.fromSms(parsed, body));
    }
    return true;
  }

  /// Drains raw_inbox: parse -> insert -> delete consumed rows, in one transaction.
  /// Dedupe happens in transactions (upi_ref UNIQUE + dedupe index), so re-drains
  /// are idempotent. Unparseable rows (promos, OTPs) are kept, not deleted.
  Future<int> drainRawInbox() async {
    var drained = 0;
    try {
      await _databaseHelper.write((db) async {
        await db.transaction((txn) async {
          final rows = await txn.query('raw_inbox', orderBy: 'received_at ASC');
          for (final row in rows) {
            final id = row['id'];
            try {
              final body = row['body'] as String?;
              if (body == null || body.trim().isEmpty) {
                await txn.delete('raw_inbox', where: 'id = ?', whereArgs: [id]);
                continue;
              }
              final parsed = _parser.parse(body);
              if (parsed == null) continue;
              final receivedAt = DateTime.fromMillisecondsSinceEpoch(
                row['received_at'] as int,
                isUtc: true,
              );
              parsed['date'] ??= receivedAt.toIso8601String();
              final persisted = await _persistParsed(parsed, body, receivedAt: receivedAt, db: txn);
              if (!persisted) continue;
              await txn.delete('raw_inbox', where: 'id = ?', whereArgs: [id]);
              drained++;
            } catch (e) {
              // ponytail: one bad row must not stall the whole queue — leave it
              // in place and keep going.
              debugPrint('Drain row $id failed: $e');
            }
            // Yield so a large backlog never blocks the UI thread (ANR).
            await Future<void>.delayed(Duration.zero);
          }
        });
      });
    } catch (e) {
      debugPrint('Drain raw_inbox failed: $e');
    }
    return drained;
  }

  /// Parse + persist one raw SMS directly (mock-data / test path).
  Future<bool> ingestSms(Map<dynamic, dynamic> args) async {
    final body = args['body'] as String?;
    if (body == null || body.trim().isEmpty) return false;
    final parsed = _parser.parse(body);
    if (parsed == null) return false;
    parsed['date'] ??= args['date'] is int
        ? DateTime.fromMillisecondsSinceEpoch(
            args['date'] as int,
            isUtc: true,
          ).toIso8601String()
        : null;
    final receivedAt = args['date'] is int
        ? DateTime.fromMillisecondsSinceEpoch(args['date'] as int, isUtc: true)
        : null;
    return await _persistParsed(parsed, body, receivedAt: receivedAt);
  }

  /// Drains SMS captured natively by Kotlin (SmsStore JSONL handoff).
  /// Kotlin appends to `raw_inbox.jsonl`; we own the DB, so we read the file with
  /// our sqflite connection and parse each line into transactions.
  Future<int> drainPendingSms() async {
    var drained = 0;
    try {
      final dir = await getDatabasesPath();
      final file = File('$dir/raw_inbox.jsonl');
      if (!await file.exists()) return 0;
      final lines = await file.readAsLines();
      if (lines.isEmpty) return 0;
      // Truncate first: we own the lines now. Anything lost is re-captured by the
      // next inbox backfill (the SMS is still in the system inbox).
      await file.writeAsString('', flush: true);
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final map = jsonDecode(line) as Map<String, dynamic>;
          final body = map['body'] as String?;
          if (body == null || body.trim().isEmpty) continue;
          final parsed = _parser.parse(body);
          if (parsed == null) continue;
          final receivedAt = map['received_at'] is int
              ? DateTime.fromMillisecondsSinceEpoch(
                  map['received_at'] as int,
                  isUtc: true,
                )
              : null;
          parsed['date'] ??= receivedAt?.toIso8601String();
          final persisted = await _persistParsed(parsed, body, receivedAt: receivedAt);
          if (!persisted) continue;
          drained++;
        } catch (e) {
          debugPrint('Pending SMS line failed: $e');
        }
      }
    } catch (e) {
      debugPrint('Drain pending SMS failed: $e');
    }
    return drained;
  }

  /// Rows stuck in raw_inbox that never parsed (promos, OTPs, foreign banks, bugs).
  /// >0 means some SMS reached the app but the parser couldn't extract a transaction.
  Future<int> unparsedCount() async {
    try {
      final result = await _databaseHelper.query((db) async {
        return await db.rawQuery('SELECT COUNT(*) AS c FROM raw_inbox');
      });
      return (result.first['c'] as num).toInt();
    } catch (e) {
      debugPrint('Unparsed count failed: $e');
      return 0;
    }
  }

  /// History backfill from the SMS provider. On Android 13+ this returns empty
  /// unless ROZZ is the default SMS handler — live capture is the primary path.
  Future<int> backfillInbox() async {
    var inserted = 0;
    try {
      final messages = await _channel.invokeMethod<List<dynamic>>('getInbox') ?? [];
      for (final m in messages) {
        final map = Map<String, dynamic>.from(m as Map);
        final body = map['body'] as String?;
        if (body == null || body.trim().isEmpty) continue;
        final parsed = _parser.parse(body);
        if (parsed == null) continue;
        final receivedAt = map['date'] is int
            ? DateTime.fromMillisecondsSinceEpoch(
                map['date'] as int,
                isUtc: true,
              )
            : null;
        parsed['date'] ??= receivedAt?.toIso8601String();
        final persisted = await _persistParsed(parsed, body, receivedAt: receivedAt);
        if (!persisted) continue;
        inserted++;
        // Yield between messages so the backfill never blocks the UI thread (ANR).
        await Future<void>.delayed(Duration.zero);
      }
    } catch (e) {
      debugPrint('Backfill failed: $e');
    }
    return inserted;
  }
}