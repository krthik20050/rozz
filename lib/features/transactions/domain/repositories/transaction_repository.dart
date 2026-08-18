import 'package:rozz/features/transactions/domain/entities/transaction.dart';

abstract class TransactionRepository {
  Future<List<Transaction>> getAllTransactions();
  Future<List<Transaction>> getTransactionsByMonth(int month, int year);
  Future<void> saveTransaction(Transaction transaction);
  Future<double?> getLastKnownBalance();
}
