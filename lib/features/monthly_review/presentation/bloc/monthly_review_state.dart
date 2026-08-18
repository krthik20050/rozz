part of 'monthly_review_bloc.dart';

abstract class MonthlyReviewState extends Equatable {
  const MonthlyReviewState();

  @override
  List<Object?> get props => [];
}

class MonthlyReviewInitial extends MonthlyReviewState {}

class MonthlyReviewLoading extends MonthlyReviewState {}

class MonthlyReviewLoaded extends MonthlyReviewState {
  final MonthlySummary summary;

  const MonthlyReviewLoaded(this.summary);

  @override
  List<Object?> get props => [summary];
}

class MonthlyReviewError extends MonthlyReviewState {
  final String message;

  const MonthlyReviewError(this.message);

  @override
  List<Object?> get props => [message];
}
