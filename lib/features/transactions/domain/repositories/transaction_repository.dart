import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/features/transactions/domain/usecases/compute_current_balance.dart';

abstract class TransactionRepository {
  Future<List<Transaction>> getAllTransactions();
  Future<List<Transaction>> getTransactionsByMonth(int month, int year);
  Future<void> saveTransaction(Transaction transaction);
  Future<double?> getLastKnownBalance();

  /// Running-balance engine result: newest bank-reported anchor + replayed
  /// ledger deltas, or [BalanceConfidence.unknown] when no anchor exists.
  Future<ComputedBalance> computeBalance();

  Future<List<Transaction>> getTransactionsBetween(
    String startIsoDate,
    String endIsoDate,
  );

  Future<List<Transaction>> getUnlinkedDebits({int limit = 400});

  Future<void> updateMerchantKey(
    int id,
    String merchantKey, {
    String? userNarration,
  });

  Future<void> deleteTransactions(List<int> ids);
}
