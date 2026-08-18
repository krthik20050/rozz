import 'package:rozz/features/insights/data/datasources/sender_label_local_datasource.dart';
import 'package:rozz/features/insights/data/models/sender_label_model.dart';
import 'package:rozz/features/insights/domain/entities/sender_label.dart';
import 'package:rozz/features/insights/domain/repositories/sender_label_repository.dart';

class SenderLabelRepositoryImpl implements SenderLabelRepository {
  final SenderLabelLocalDatasource _localDatasource;

  SenderLabelRepositoryImpl(this._localDatasource);

  @override
  Future<List<SenderLabel>> getAll() async {
    return await _localDatasource.getAll();
  }

  @override
  Future<SenderLabel?> getByKey(String key) async {
    return await _localDatasource.getByKey(key);
  }

  @override
  Future<void> upsert(SenderLabel label) async {
    await _localDatasource.upsert(SenderLabelModel(
      key: label.key,
      label: label.label,
    ));
  }

  @override
  Future<void> delete(String key) async {
    await _localDatasource.delete(key);
  }
}
