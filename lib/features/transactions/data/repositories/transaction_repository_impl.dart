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
    );
    await _localDatasource.insertTransaction(model);
  }

  @override
  Future<double?> getLastKnownBalance() async {
    return await _localDatasource.getLastKnownBalance();
  }
}
