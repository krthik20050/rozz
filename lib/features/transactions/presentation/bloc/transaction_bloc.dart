import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';

part 'transaction_event.dart';
part 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository _repository;

  TransactionBloc(this._repository) : super(TransactionInitial()) {
    on<LoadTransactions>(_onLoadTransactions);
    on<AddTransaction>(_onAddTransaction);
  }

  Future<void> _onLoadTransactions(
    LoadTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoading());
    try {
      final transactions = await _repository.getAllTransactions();
      final balance = await _repository.getLastKnownBalance();
      emit(TransactionLoaded(transactions, balance));
    } catch (e) {
      emit(TransactionError(e.toString()));
    }
  }

  Future<void> _onAddTransaction(
    AddTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      await _repository.saveTransaction(event.transaction);
      add(LoadTransactions());
    } catch (e) {
      emit(TransactionError(e.toString()));
    }
  }
}
