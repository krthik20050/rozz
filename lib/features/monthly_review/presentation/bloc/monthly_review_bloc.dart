import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rozz/features/insights/domain/entities/monthly_summary.dart';
import 'package:rozz/features/insights/domain/usecases/compute_monthly_summary.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';

part 'monthly_review_event.dart';
part 'monthly_review_state.dart';

class MonthlyReviewBloc extends Bloc<MonthlyReviewEvent, MonthlyReviewState> {
  final TransactionRepository _transactionRepository;
  final ComputeMonthlySummary _computeMonthlySummary;

  MonthlyReviewBloc(this._transactionRepository, this._computeMonthlySummary)
      : super(MonthlyReviewInitial()) {
    on<LoadMonthlyReview>(_onLoadMonthlyReview);
  }

  Future<void> _onLoadMonthlyReview(
    LoadMonthlyReview event,
    Emitter<MonthlyReviewState> emit,
  ) async {
    emit(MonthlyReviewLoading());
    try {
      final prior = DateTime(event.year, event.month - 1, 1);
      final monthTransactions = await _transactionRepository
          .getTransactionsByMonth(event.month, event.year);
      final priorTransactions = await _transactionRepository
          .getTransactionsByMonth(prior.month, prior.year);

      final summary = _computeMonthlySummary(
        monthTransactions: monthTransactions,
        priorMonthTransactions: priorTransactions,
        month: event.month,
        year: event.year,
      );
      emit(MonthlyReviewLoaded(summary));
    } catch (e) {
      emit(MonthlyReviewError(e.toString()));
    }
  }
}
