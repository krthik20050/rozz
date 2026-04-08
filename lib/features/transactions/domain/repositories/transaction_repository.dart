import 'package:rozz/features/transactions/domain/entities/transaction.dart';

abstract class TransactionRepository {
  Future<List<Transaction>> getAllTransactions();
  Future<void> saveTransaction(Transaction transaction);
  Future<double?> getLastKnownBalance();
  Future<List<Transaction>> getUncategorizedTransactions({int limit = 20});
  Future<void> updateCategory(int id, String category);
}
