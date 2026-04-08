import 'package:flutter/foundation.dart';
import 'package:rozz/core/security/secure_storage_service.dart';
import 'package:rozz/core/services/supabase_service.dart';
import 'package:rozz/features/mab/data/datasources/mab_local_datasource.dart';
import 'package:rozz/features/mab/data/models/mab_record_model.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';

/// Result returned by [SyncService.syncAll].
class SyncResult {
  final bool success;
  final String message;
  final int pushed;
  final int pulled;

  const SyncResult({
    required this.success,
    required this.message,
    this.pushed = 0,
    this.pulled = 0,
  });
}

/// Bidirectional sync between local SQLite and a user-supplied Supabase
/// project.  Sync is always device-scoped: every row carries a [device_id]
/// so a single Supabase project can hold data from multiple devices.
///
/// Required Supabase SQL (run once in the SQL Editor):
/// ```sql
/// create table if not exists transactions (
///   id          bigserial primary key,
///   device_id   text not null,
///   local_id    integer,
///   date        text not null,
///   amount      real not null,
///   direction   text not null,
///   label_type  text not null,
///   recipient_name text,
///   upi_id      text,
///   balance_after real,
///   source      text,
///   upi_ref_number text,
///   category    text,
///   created_at  timestamptz default now(),
///   unique(device_id, local_id)
/// );
///
/// create table if not exists mab_history (
///   id                bigserial primary key,
///   device_id         text not null,
///   date              text not null,
///   end_of_day_balance real not null,
///   month             integer not null,
///   year              integer not null,
///   created_at        timestamptz default now(),
///   unique(device_id, date)
/// );
/// ```
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  TransactionLocalDatasourceImpl? _txDatasource;
  MabLocalDatasourceImpl? _mabDatasource;
  SecureStorageService? _secureStorage;

  /// Must be called once (e.g. in main()) before [syncAll] is used.
  void init({
    required TransactionLocalDatasourceImpl txDatasource,
    required MabLocalDatasourceImpl mabDatasource,
    required SecureStorageService secureStorage,
  }) {
    _txDatasource = txDatasource;
    _mabDatasource = mabDatasource;
    _secureStorage = secureStorage;
  }

  // ── Device identity ────────────────────────────────────────────────────────

  Future<String> _getDeviceId() async {
    var id = await _secureStorage!.readValue('DEVICE_ID');
    if (id == null || id.isEmpty) {
      id = SupabaseService.generateDeviceId();
      await _secureStorage!.writeValue('DEVICE_ID', id);
    }
    return id;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<SyncResult> syncAll() async {
    final supabase = SupabaseService();
    if (!supabase.isInitialized) {
      return const SyncResult(
          success: false, message: 'Supabase not configured');
    }
    if (_txDatasource == null ||
        _mabDatasource == null ||
        _secureStorage == null) {
      return const SyncResult(
          success: false, message: 'SyncService not initialized');
    }

    int pushed = 0;
    int pulled = 0;

    try {
      final deviceId = await _getDeviceId();
      final client = supabase.client!;

      // ── Push transactions ────────────────────────────────────────────────
      final transactions = await _txDatasource!.getAllTransactions();
      final txRows = transactions
          .where((t) => t.id != null)
          .map((t) => {
                'device_id': deviceId,
                'local_id': t.id,
                'date': t.date,
                'amount': t.amount,
                'direction': t.direction,
                'label_type': t.labelType,
                'recipient_name': t.recipientName,
                'upi_id': t.upiId,
                'balance_after': t.balanceAfter,
                'source': t.source,
                'upi_ref_number': t.upiRefNumber,
                'category': t.category,
              })
          .toList();

      if (txRows.isNotEmpty) {
        await client
            .from('transactions')
            .upsert(txRows, onConflict: 'device_id,local_id');
        pushed += txRows.length;
      }

      // ── Pull transactions ────────────────────────────────────────────────
      final remoteTxs = await client
          .from('transactions')
          .select()
          .eq('device_id', deviceId)
          .order('date', ascending: false)
          .limit(500) as List<dynamic>;

      for (final row in remoteTxs) {
        try {
          final model = TransactionModel(
            id: row['local_id'] as int?,
            date: row['date'] as String,
            amount: (row['amount'] as num).toDouble(),
            direction: row['direction'] as String,
            labelType: row['label_type'] as String,
            recipientName: row['recipient_name'] as String?,
            upiId: row['upi_id'] as String?,
            balanceAfter: row['balance_after'] != null
                ? (row['balance_after'] as num).toDouble()
                : null,
            source: row['source'] as String? ?? 'sync',
            upiRefNumber: row['upi_ref_number'] as String?,
            category: row['category'] as String?,
          );
          await _txDatasource!.insertTransaction(model);
          pulled++;
        } catch (e) {
          debugPrint('SyncService: pull tx row error: $e');
        }
      }

      // ── Push MAB history (last 3 months) ─────────────────────────────────
      final now = DateTime.now();
      final mabRows = <Map<String, dynamic>>[];
      for (int i = 0; i < 3; i++) {
        int month = now.month - i;
        int year = now.year;
        if (month <= 0) {
          month += 12;
          year -= 1;
        }
        final records = await _mabDatasource!.getMonthRecords(month, year);
        for (final r in records) {
          mabRows.add({
            'device_id': deviceId,
            'date': r.date,
            'end_of_day_balance': r.endOfDayBalance,
            'month': r.month,
            'year': r.year,
          });
        }
      }

      if (mabRows.isNotEmpty) {
        await client
            .from('mab_history')
            .upsert(mabRows, onConflict: 'device_id,date');
        pushed += mabRows.length;
      }

      // ── Pull MAB history ─────────────────────────────────────────────────
      final remoteMab = await client
          .from('mab_history')
          .select()
          .eq('device_id', deviceId)
          .order('date', ascending: false)
          .limit(365) as List<dynamic>;

      for (final row in remoteMab) {
        try {
          final record = MabRecordModel(
            date: row['date'] as String,
            endOfDayBalance:
                (row['end_of_day_balance'] as num).toDouble(),
            month: row['month'] as int,
            year: row['year'] as int,
          );
          await _mabDatasource!.insertEodBalance(record);
          pulled++;
        } catch (e) {
          debugPrint('SyncService: pull mab row error: $e');
        }
      }

      // ── Persist last-sync timestamp ──────────────────────────────────────
      await _secureStorage!.writeValue(
        'LAST_SYNC_AT',
        DateTime.now().toUtc().toIso8601String(),
      );

      return SyncResult(
        success: true,
        message: '$pushed uploaded, $pulled downloaded',
        pushed: pushed,
        pulled: pulled,
      );
    } catch (e) {
      debugPrint('SyncService.syncAll error: $e');
      return SyncResult(success: false, message: 'Sync failed: $e');
    }
  }
}
