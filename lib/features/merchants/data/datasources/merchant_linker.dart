import 'package:rozz/features/merchants/data/datasources/merchant_local_datasource.dart';
import 'package:rozz/shared/utils/merchant_key.dart';
import 'package:sqflite/sqflite.dart';

/// The outcome of resolving one payment row to a merchant.
class MerchantResolution {
  /// Canonical merchant key ('swiggy' / 'rahulverma').
  final String merchantKey;

  /// Display name when the merchant row already exists (null for a brand slug
  /// with no profile row yet — the UI resolves brand display names itself).
  final String? canonicalName;

  /// The merchant's unambiguous default description — auto-copied onto a new
  /// payment at ingest (this is the forward "regression"). Null when the user
  /// never described this merchant.
  final String? defaultDescription;

  /// When true the merchant carries conflicting user descriptions — the
  /// description must NOT auto-apply; the UI asks instead.
  final bool conflict;

  const MerchantResolution({
    required this.merchantKey,
    this.canonicalName,
    this.defaultDescription,
    this.conflict = false,
  });
}

/// Resolves debit rows (SMS or statement) to one canonical merchant.
///
/// Priority: deterministic brand slug (SWIGGY -> 'swiggy', no DB row needed)
/// > merchant_aliases (person VPAs / raw names previously linked). Unknown
/// payees return null and stay unlinked until the AI clustering pass or the
/// user's first description creates the merchant.
class MerchantLinker {
  final MerchantLocalDatasource _merchants;

  MerchantLinker(this._merchants);

  /// Candidate alias keys for a payment row, ordered by confidence.
  List<String> candidateKeys({
    String? recipientName,
    String? upiId,
    String? labelType,
    String direction = 'debit',
  }) =>
      MerchantKey.aliasKeysFor(
        recipientName: recipientName,
        upiId: upiId,
        labelType: labelType,
        direction: direction,
      );

  /// Resolves a debit row. Pass the open [db] when already inside a caller
  /// transaction (ingest/statement) so alias reads join it; null routes reads
  /// through the WriteQueue.
  Future<MerchantResolution?> resolve(
    DatabaseExecutor? db, {
    required String? recipientName,
    String? upiId,
    String? labelType,
    String direction = 'debit',
  }) async {
    final raw = recipientName ?? '';
    if (direction != 'debit' || raw.trim().isEmpty) return null;

    // 1) Deterministic brand identity — no alias row needed.
    final brandSlug = MerchantKey.brandCanonicalSlug(raw, labelType, direction);
    if (brandSlug != null) {
      final profile = db == null
          ? await _merchants.getMerchant(brandSlug)
          : await _merchants.getMerchantWithDb(db, brandSlug);
      return MerchantResolution(
        merchantKey: brandSlug,
        canonicalName: profile?.canonicalName,
        defaultDescription: profile?.description,
        conflict: profile?.conflict ?? false,
      );
    }

    // 2) Alias store: person VPAs / raw names linked before.
    final keys = candidateKeys(
      recipientName: recipientName,
      upiId: upiId,
      labelType: labelType,
      direction: direction,
    );
    final merchant = db == null
        ? await _merchants.resolveByAliases(keys)
        : await _merchants.resolveByAliasesWithDb(db, keys);
    if (merchant == null) return null;
    return MerchantResolution(
      merchantKey: merchant.merchantKey,
      canonicalName: merchant.canonicalName,
      defaultDescription: merchant.description,
      conflict: merchant.conflict,
    );
  }
}
