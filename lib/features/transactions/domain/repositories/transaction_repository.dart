import 'package:rozz/features/transactions/domain/entities/transaction.dart';

abstract class TransactionRepository {
  Future<List<Transaction>> getAllTransactions();
  Future<void> saveTransaction(Transaction transaction);
  Future<double?> getLastKnownBalance();
}
