import 'package:workmanager/workmanager.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/core/services/transaction_sync_service.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';
import 'package:rozz/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:rozz/features/mab/data/datasources/mab_local_datasource.dart';
import 'package:rozz/features/mab/data/models/mab_record_model.dart';
import 'package:intl/intl.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'eodBalanceTask':
        return await _handleEodBalanceTask();
      case 'smsBackfillTask':
        return await _handleSmsBackfillTask();
      default:
        return Future.value(true);
    }
  });
}

/// Background SMS sync — the heavy lifting moves out of app startup. Drains
/// whatever the native listener captured, then backfills the inbox for any
/// SMS that arrived while the app was dead.
Future<bool> _handleSmsBackfillTask() async {
  try {
    final databaseHelper = DatabaseHelper();
    final transactionDatasource = TransactionLocalDatasourceImpl(databaseHelper);
    final repository = TransactionRepositoryImpl(transactionDatasource);
    final service = TransactionSyncService(repository, databaseHelper, SmsParser());
    await service.drainPendingSms();
    await service.drainRawInbox();
    await service.backfillInbox();
    return true;
  } catch (e) {
    return false;
  }
}

Future<bool> _handleEodBalanceTask() async {
  try {
    final databaseHelper = DatabaseHelper();
    final transactionDatasource = TransactionLocalDatasourceImpl(databaseHelper);
    final mabDatasource = MabLocalDatasourceImpl(databaseHelper);

    // 1. Get last known balance
    final lastBalance = await transactionDatasource.getLastKnownBalance();
    if (lastBalance == null) return true; // Nothing to record

    // 2. Today in IST
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // 3. Get last record to handle backfill
    final lastRecord = await mabDatasource.getLastRecord();

    if (lastRecord != null) {
      final lastDate = DateTime.parse(lastRecord.date);
      final difference = now.difference(lastDate).inDays;

      if (difference > 1) {
        // Backfill missing days
        for (int i = 1; i < difference; i++) {
          final fillDate = lastDate.add(Duration(days: i));
          final fillDateStr = DateFormat('yyyy-MM-dd').format(fillDate);
          await mabDatasource.insertEodBalance(MabRecordModel(
            date: fillDateStr,
            endOfDayBalance: lastRecord.endOfDayBalance,
            month: fillDate.month,
            year: fillDate.year,
          ));
        }
      }
    }

    // 4. Insert today's balance
    await mabDatasource.insertEodBalance(MabRecordModel(
      date: todayStr,
      endOfDayBalance: lastBalance,
      month: now.month,
      year: now.year,
    ));

    return true;
  } catch (e) {
    return false;
  }
}

class WorkmanagerService {
  static const String eodBalanceTask = "eodBalanceTask";

  static const String smsBackfillTask = "smsBackfillTask";

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);

    // EOD balance update
    await Workmanager().registerPeriodicTask(
      "1",
      eodBalanceTask,
      frequency: const Duration(hours: 12),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );

    // SMS backfill in the background every 6h — the app no longer re-parses
    // the whole inbox on every launch.
    await Workmanager().registerPeriodicTask(
      "3",
      smsBackfillTask,
      frequency: const Duration(hours: 6),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}


