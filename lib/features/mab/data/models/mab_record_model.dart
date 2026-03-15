import 'package:rozz/features/mab/domain/entities/mab_record.dart';

class MabRecordModel extends MabRecord {
  const MabRecordModel({
    super.id,
    required super.date,
    required super.endOfDayBalance,
    required super.month,
    required super.year,
  });

  factory MabRecordModel.fromMap(Map<String, dynamic> map) {
    return MabRecordModel(
      id: map['id'] as int?,
      date: map['date'] as String,
      endOfDayBalance: (map['end_of_day_balance'] as num).toDouble(),
      month: map['month'] as int,
      year: map['year'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'end_of_day_balance': endOfDayBalance,
      'month': month,
      'year': year,
    };
  }
}
