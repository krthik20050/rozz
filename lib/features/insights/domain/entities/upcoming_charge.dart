import 'package:equatable/equatable.dart';

/// A detected recurring charge expected in the coming days, with a predicted
/// next charge date derived from real transaction history.
class UpcomingCharge extends Equatable {
  final String merchant;
  final double amount;
  final DateTime predictedDate;

  const UpcomingCharge({
    required this.merchant,
    required this.amount,
    required this.predictedDate,
  });

  @override
  List<Object?> get props => [merchant, amount, predictedDate];
}
