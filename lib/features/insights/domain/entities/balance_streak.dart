import 'package:equatable/equatable.dart';

/// How many recorded days in a month kept the balance at or above the MAB
/// threshold. [daysRecorded] is the denominator so the figure is honest when
/// only part of the month has data.
class BalanceStreak extends Equatable {
  final int daysAbove;
  final int daysRecorded;

  const BalanceStreak({required this.daysAbove, required this.daysRecorded});

  @override
  List<Object?> get props => [daysAbove, daysRecorded];
}
