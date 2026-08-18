import 'package:rozz/features/insights/domain/entities/sender_label.dart';

abstract class SenderLabelRepository {
  Future<List<SenderLabel>> getAll();
  Future<SenderLabel?> getByKey(String key);
  Future<void> upsert(SenderLabel label);
  Future<void> delete(String key);
}
