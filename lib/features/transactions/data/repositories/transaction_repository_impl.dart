import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionLocalDatasource _localDatasource;

  TransactionRepositoryImpl(this._localDatasource);

  @override
  Future<List<Transaction>> getAllTransactions() async {
    final models = await _localDatasource.getAllTransactions();
    return models; // TransactionModel extends Transaction
  }

  @override
  Future<void> saveTransaction(Transaction transaction) async {
    final model = TransactionModel(
      id: transaction.id,
      date: transaction.date,
      amount: transaction.amount,
      direction: transaction.direction,
      labelType: transaction.labelType,
      recipientName: transaction.recipientName,
      upiId: transaction.upiId,
      balanceAfter: transaction.balanceAfter,
      source: transaction.source,
      upiRefNumber: transaction.upiRefNumber,
      rawSms: transaction.rawSms,
      category: transaction.category,
    );
    await _localDatasource.insertTransaction(model);
  }

  @override
  Future<double?> getLastKnownBalance() async {
    return await _localDatasource.getLastKnownBalance();
  }

  @override
  Future<List<Transaction>> getUncategorizedTransactions({int limit = 20}) async {
    return await _localDatasource.getUncategorizedTransactions(limit: limit);
  }

  @override
  Future<void> updateCategory(int id, String category) async {
    await _localDatasource.updateCategory(id, category);
  }
}
