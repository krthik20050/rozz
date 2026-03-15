import 'package:rozz/features/mab/domain/entities/mab_record.dart';

abstract class MabRepository {
  Future<List<MabRecord>> getMonthRecords(int month, int year);
  Future<void> insertEodBalance(MabRecord record);
  Future<List<String>> getMissingDays(int month, int year);
}
