import 'package:rozz/features/mab/data/datasources/mab_local_datasource.dart';
import 'package:rozz/features/mab/data/models/mab_record_model.dart';
import 'package:rozz/features/mab/domain/entities/mab_record.dart';
import 'package:rozz/features/mab/domain/repositories/mab_repository.dart';

class MabRepositoryImpl implements MabRepository {
  final MabLocalDatasource _localDatasource;

  MabRepositoryImpl(this._localDatasource);

  @override
  Future<List<MabRecord>> getMonthRecords(int month, int year) async {
    return await _localDatasource.getMonthRecords(month, year);
  }

  @override
  Future<void> insertEodBalance(MabRecord record) async {
    final model = MabRecordModel(
      id: record.id,
      date: record.date,
      endOfDayBalance: record.endOfDayBalance,
      month: record.month,
      year: record.year,
    );
    await _localDatasource.insertEodBalance(model);
  }

  @override
  Future<List<String>> getMissingDays(int month, int year) async {
    return await _localDatasource.getMissingDays(month, year);
  }
}
