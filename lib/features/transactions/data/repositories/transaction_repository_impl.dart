import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:rozz/features/transactions/domain/usecases/compute_current_balance.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionLocalDatasource _localDatasource;

  TransactionRepositoryImpl(this._localDatasource);

  @override
  Future<List<Transaction>> getAllTransactions() async {
    final models = await _localDatasource.getAllTransactions();
    return models; // TransactionModel extends Transaction
  }

  @override
  Future<List<Transaction>> getTransactionsByMonth(int month, int year) async {
    final models = await _localDatasource.getTransactionsByMonth(month, year);
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
      merchantKey: transaction.merchantKey,
      userNarration: transaction.userNarration,
    );
    await _localDatasource.insertTransaction(model);
  }

  @override
  Future<List<Transaction>> getTransactionsBetween(
    String startIsoDate,
    String endIsoDate,
  ) async {
    final models = await _localDatasource.getTransactionsBetween(startIsoDate, endIsoDate);
    return models;
  }

  @override
  Future<List<Transaction>> getUnlinkedDebits({int limit = 400}) async {
    final models = await _localDatasource.getUnlinkedDebits(limit: limit);
    return models;
  }

  @override
  Future<void> updateMerchantKey(
    int id,
    String merchantKey, {
    String? userNarration,
  }) async {
    await _localDatasource.updateMerchantKey(id, merchantKey, userNarration: userNarration);
  }

  @override
  Future<void> deleteTransactions(List<int> ids) async {
    await _localDatasource.deleteTransactions(ids);
  }

  @override
  Future<double?> getLastKnownBalance() async {
    return await _localDatasource.getLastKnownBalance();
  }

  @override
  Future<ComputedBalance> computeBalance() async {
    return await _localDatasource.computeBalance();
  }
}
