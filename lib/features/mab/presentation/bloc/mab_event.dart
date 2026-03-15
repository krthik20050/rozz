part of 'mab_bloc.dart';

abstract class MabEvent extends Equatable {
  const MabEvent();

  @override
  List<Object?> get props => [];
}

class LoadMabStatus extends MabEvent {
  final int month;
  final int year;
  final DateTime? now;

  const LoadMabStatus({required this.month, required this.year, this.now});

  @override
  List<Object?> get props => [month, year, now];
}

class RecordEodBalance extends MabEvent {
  final double balance;

  const RecordEodBalance(this.balance);

  @override
  List<Object?> get props => [balance];
}
