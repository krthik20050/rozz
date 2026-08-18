import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:rozz/core/services/ai_service.dart';

part 'transaction_event.dart';
part 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository _repository;
  final AiService _aiService;

  TransactionBloc(this._repository, this._aiService) : super(TransactionInitial()) {
    on<LoadTransactions>(_onLoadTransactions);
    on<AddTransaction>(_onAddTransaction);
    on<CategorizeTransactions>(_onCategorizeTransactions);
  }

  Future<void> _onLoadTransactions(
    LoadTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoading());
    try {
      final transactions = await _repository.getAllTransactions();
      
      // Calculate running balance from transactions if lastKnown is null/zero
      double? balance = await _repository.getLastKnownBalance();

      if (balance == null || balance == 0) {
        double calculatedBalance = 0;
        for (var tx in transactions) {
          if (tx.direction == 'credit') {
            calculatedBalance += tx.amount;
          } else {
            calculatedBalance -= tx.amount;
          }
        }
        balance = calculatedBalance;
      }

      emit(TransactionLoaded(transactions, balance));

      // Note: AI auto-categorization is intentionally NOT fired here. On
      // the free tier a sync of hundreds of transactions burns the whole
      // rate limit in seconds (starving the chat). Categories already come
      // from the deterministic local brand resolver (MerchantBrandResolver)
      // everywhere in the UI — the AI pass was redundant quota spending.
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

  Future<void> _onCategorizeTransactions(
    CategorizeTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! TransactionLoaded) return;

    final uncategorized = currentState.transactions.where((tx) => tx.category == null).toList();
    if (uncategorized.isEmpty) return;
    // ponytail: cap per cycle — a 500-SMS backfill must not fire 500 AI calls
    // at once; the rest get categorized on subsequent load cycles.
    final batch = uncategorized.take(30).toList();

    var savedAny = false;
    for (var tx in batch) {
      try {
        final narration = tx.recipientName ?? tx.rawSms ?? 'Unknown';
        final category = await _aiService.categorizeTransaction(narration);
        
        if (category != null) {
          final updatedTx = Transaction(
            id: tx.id,
            date: tx.date,
            amount: tx.amount,
            direction: tx.direction,
            labelType: tx.labelType,
            recipientName: tx.recipientName,
            upiId: tx.upiId,
            balanceAfter: tx.balanceAfter,
            source: tx.source,
            upiRefNumber: tx.upiRefNumber,
            rawSms: tx.rawSms,
            category: category,
          );
          
          await _repository.saveTransaction(updatedTx);
          savedAny = true;
        }
      } catch (e) {
        // ignore: avoid_print
        print('Categorization error for transaction ${tx.id}: $e');
      }
    }
    
    // Only reload if something changed — otherwise an AI failure would loop forever.
    if (savedAny) add(LoadTransactions());
  }
}