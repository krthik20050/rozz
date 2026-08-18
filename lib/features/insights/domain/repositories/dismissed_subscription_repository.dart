/// Read/write access to the set of dismissed (not-a-subscription) merchants.
abstract class DismissedSubscriptionRepository {
  Future<Set<String>> getAll();
  Future<void> dismiss(String merchantKey);
  Future<void> restore(String merchantKey);
}