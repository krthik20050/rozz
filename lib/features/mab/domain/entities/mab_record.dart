import 'package:equatable/equatable.dart';

class MabRecord extends Equatable {
  final int? id;
  final String date; // yyyy-MM-dd IST
  final double endOfDayBalance;
  final int month;
  final int year;

  const MabRecord({
    this.id,
    required this.date,
    required this.endOfDayBalance,
    required this.month,
    required this.year,
  });

  @override
  List<Object?> get props => [id, date, endOfDayBalance, month, year];
}
