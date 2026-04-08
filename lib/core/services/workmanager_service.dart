import 'package:workmanager/workmanager.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/core/security/secure_storage_service.dart';
import 'package:rozz/core/services/gemini_service.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/mab/data/datasources/mab_local_datasource.dart';
import 'package:rozz/features/mab/data/models/mab_record_model.dart';
import 'package:intl/intl.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'eodBalanceTask':
        return await _handleEodBalanceTask();
      case 'geminiSyncTask':
        return await _handleGeminiSyncTask();
      default:
        return Future.value(true);
    }
  });
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

Future<bool> _handleGeminiSyncTask() async {
  try {
    final databaseHelper = DatabaseHelper();
    final transactionDatasource = TransactionLocalDatasourceImpl(databaseHelper);
    final secureStorage = SecureStorageService();
    final geminiService = GeminiService(secureStorage);

    final uncategorized = await transactionDatasource.getUncategorizedTransactions(limit: 20);
    if (uncategorized.isEmpty) return true;

    for (final tx in uncategorized) {
      if (tx.id == null) continue;
      final parts = <String>[];
      if (tx.recipientName != null) parts.add(tx.recipientName!);
      parts.add(tx.labelType.replaceAll('_', ' '));
      if (tx.rawSms != null && tx.rawSms!.length <= 160) parts.add(tx.rawSms!);
      final narration = parts.join(' – ');
      final category = await geminiService.categorizeTransaction(narration);
      if (category != null && category.isNotEmpty) {
        await transactionDatasource.updateCategory(tx.id!, category);
      }
    }

    return true;
  } catch (e) {
    return false;
  }
}

class WorkmanagerService {
  static const String eodBalanceTask = "eodBalanceTask";

  static const String geminiSyncTask = "geminiSyncTask";

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    // EOD balance update
    await Workmanager().registerPeriodicTask(
      "1",
      eodBalanceTask,
      frequency: const Duration(hours: 12),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );

    // AI Insight and categorization sync (only when connected)
    await Workmanager().registerPeriodicTask(
      "2",
      geminiSyncTask,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}


