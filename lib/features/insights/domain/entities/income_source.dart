import 'package:equatable/equatable.dart';

/// One source of money coming in within a month: credits grouped by recipient.
class IncomeSource extends Equatable {
  final String recipient;
  final double amount;
  final int count;

  const IncomeSource({
    required this.recipient,
    required this.amount,
    required this.count,
  });

  @override
  List<Object?> get props => [recipient, amount, count];
}
