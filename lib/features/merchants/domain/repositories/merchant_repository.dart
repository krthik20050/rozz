import 'package:rozz/features/merchants/data/datasources/merchant_local_datasource.dart';
import 'package:rozz/features/merchants/domain/entities/merchant.dart';

/// Read/write the merchant identity store. Description propagation touches the
/// `transactions` table atomically with the `merchants` row (see
/// [MerchantLocalDatasource.applyDescriptionWithDb]).
abstract class MerchantRepository {
  Future<List<Merchant>> getMerchants();

  Future<Merchant?> getMerchant(String merchantKey);

  /// Creates the merchant row when missing (idempotent, preserves existing
  /// description/conflict state).
  Future<void> createMerchant(
    String merchantKey,
    String canonicalName,
    String source,
  );

  Future<DescriptionApply> applyDescription({
    required String merchantKey,
    required String description,
    bool merchantWide = false,
    int? triggerTxId,
  });

  Future<DescriptionApply> clearDescription({
    required String merchantKey,
    String? currentDescription,
  });

  /// Points a raw identity (name slug / VPA local part) at the merchant so
  /// future payments resolve without another AI pass.
  Future<void> addAlias(String aliasKey, String merchantKey);
}
