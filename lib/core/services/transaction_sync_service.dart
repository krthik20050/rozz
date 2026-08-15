import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
              if (parsed == null || parsed['amount'] == null) continue;
              parsed['date'] ??= DateTime.fromMillisecondsSinceEpoch(
                row['received_at'] as int,
                isUtc: true,
              ).toIso8601String();
              await txn.insert(
                'transactions',
                TransactionModel.fromSms(parsed, body).toMap(),
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
              await txn.delete('raw_inbox', where: 'id = ?', whereArgs: [id]);
              drained++;
            } catch (e) {
              // ponytail: one bad row must not stall the whole queue — leave it
              // in place and keep going.
              debugPrint('Drain row $id failed: $e');
            }
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
    if (parsed == null || parsed['amount'] == null) return false;
    parsed['date'] ??= args['date'] is int
        ? DateTime.fromMillisecondsSinceEpoch(
            args['date'] as int,
            isUtc: true,
          ).toIso8601String()
        : null;
    await _repository.saveTransaction(TransactionModel.fromSms(parsed, body));
    return true;
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
        if (parsed == null || parsed['amount'] == null) continue;
        parsed['date'] ??= map['date'] is int
            ? DateTime.fromMillisecondsSinceEpoch(
                map['date'] as int,
                isUtc: true,
              ).toIso8601String()
            : null;
        await _repository.saveTransaction(TransactionModel.fromSms(parsed, body));
        inserted++;
      }
    } catch (e) {
      debugPrint('Backfill failed: $e');
    }
    return inserted;
  }
}