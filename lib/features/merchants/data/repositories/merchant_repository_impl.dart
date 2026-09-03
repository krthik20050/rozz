import 'package:rozz/features/merchants/data/datasources/merchant_local_datasource.dart';
import 'package:rozz/features/merchants/domain/entities/merchant.dart';
import 'package:rozz/features/merchants/domain/repositories/merchant_repository.dart';

class MerchantRepositoryImpl implements MerchantRepository {
  final MerchantLocalDatasource _local;

  MerchantRepositoryImpl(this._local);

  @override
  Future<List<Merchant>> getMerchants() => _local.getAllMerchants();

  @override
  Future<Merchant?> getMerchant(String merchantKey) => _local.getMerchant(merchantKey);

  @override
  Future<void> createMerchant(
    String merchantKey,
    String canonicalName,
    String source,
  ) async {
    final existing = await _local.getMerchant(merchantKey);
    if (existing == null) {
      await _local.upsertMerchant(
        MerchantDraft(
          merchantKey: merchantKey,
          canonicalName: canonicalName,
          source: source,
        ),
      );
    }
  }

  @override
  Future<DescriptionApply> applyDescription({
    required String merchantKey,
    required String description,
    bool merchantWide = false,
    int? triggerTxId,
  }) =>
      _local.applyDescription(
        merchantKey: merchantKey,
        description: description,
        merchantWide: merchantWide,
        triggerTxId: triggerTxId,
      );

  @override
  Future<DescriptionApply> clearDescription({
    required String merchantKey,
    String? currentDescription,
  }) =>
      _local.clearDescription(
        merchantKey: merchantKey,
        currentDescription: currentDescription,
      );

  @override
  Future<void> addAlias(String aliasKey, String merchantKey) async {
    await _local.addAlias(aliasKey, merchantKey, 'name');
  }
}
