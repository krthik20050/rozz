part of 'monthly_review_bloc.dart';

abstract class MonthlyReviewEvent extends Equatable {
  const MonthlyReviewEvent();

  @override
  List<Object?> get props => [];
}

class LoadMonthlyReview extends MonthlyReviewEvent {
  final int month;
  final int year;

  const LoadMonthlyReview({required this.month, required this.year});

  @override
  List<Object?> get props => [month, year];
}
