import 'package:rozz/features/insights/data/datasources/dismissed_subscription_local_datasource.dart';
import 'package:rozz/features/insights/domain/repositories/dismissed_subscription_repository.dart';

class DismissedSubscriptionRepositoryImpl
    implements DismissedSubscriptionRepository {
  final DismissedSubscriptionLocalDatasource _datasource;

  DismissedSubscriptionRepositoryImpl(this._datasource);

  @override
  Future<Set<String>> getAll() => _datasource.getAll();

  @override
  Future<void> dismiss(String merchantKey) => _datasource.dismiss(merchantKey);

  @override
  Future<void> restore(String merchantKey) => _datasource.restore(merchantKey);
}