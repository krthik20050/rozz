import 'package:rozz/shared/utils/merchant_brand_resolver.dart';

/// Normalization + candidate extraction for merchant identity ("the central
/// ID"). Every raw spelling of a payee — SMS recipient name, UPI VPA local
/// part, statement payee name — reduces to candidate *alias keys* (slugged,
/// lowercased, alphanumeric-only strings). Looked up in `merchant_aliases`
/// they resolve to one canonical merchant; when the payee is a known brand the
/// brand's canonical slug IS the merchant key (deterministic, no DB row needed).
///
/// Pure Dart — unit-testable without a database.
class MerchantKey {
  MerchantKey._();

  /// Slug key for any raw identity string: lowercase, letters+digits only.
  /// "SWIGGY", "Swiggy India", " swiggy! " -> "swiggy".
  static String slug(String raw) {
    final lower = raw.toLowerCase();
    final buffer = StringBuffer();
    for (final code in lower.codeUnits) {
      final c = String.fromCharCode(code);
      if (RegExp(r'[a-z0-9]').hasMatch(c)) buffer.write(c);
    }
    return buffer.toString();
  }

  /// Local part of a UPI VPA ("swiggy@ybl" -> "swiggy", "9898..@ybl" ->
  /// digits). Null when [upiId] has no VPA shape.
  static String? vpaLocalPart(String? upiId) {
    if (upiId == null || upiId.isEmpty) return null;
    final at = upiId.indexOf('@');
    if (at <= 0) return null;
    return upiId.substring(0, at);
  }

  /// Slugs that identify generic bank-payment labels (not payees) so
  /// [brandCanonicalSlug] can tell a real brand from the fallback bucket.
  static const Set<String> _genericBrandNames = {
    'upi transfer',
    'atm cash',
    'bank transfer',
    'salary deposit',
    'insurance',
    'unknown',
  };

  /// When [raw] resolves through [MerchantBrandResolver] to a *named* brand
  /// ("SPOTIFY AB" -> "Spotify"), returns that brand's slug ("spotify") — a
  /// deterministic merchant key that does not need an alias row. Null for
  /// generic fallbacks ("UPI Transfer") and for raw names the resolver maps
  /// to themselves.
  static String? brandCanonicalSlug(String raw, String? labelType, String direction) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final brand = MerchantBrandResolver.resolve(trimmed, labelType, direction);
    final brandSlug = slug(brand.name);
    if (brandSlug.isEmpty || _genericBrandNames.contains(brandSlug)) return null;
    // The resolver echoes back unknown names (title-cased) — only a canonical
    // brand that differs from the raw slug is a real identity win.
    if (brandSlug == slug(trimmed)) return null;
    return brandSlug;
  }

  /// Ordered, deduped candidate alias keys for one transaction/row. Order
  /// matters: brand slugs first (deterministic), then VPA local parts, then
  /// the raw name slug.
  static List<String> aliasKeysFor({
    String? recipientName,
    String? upiId,
    String? labelType,
    String direction = 'debit',
  }) {
    final candidates = <String>[];
    void add(String? value) {
      if (value == null || value.trim().isEmpty) return;
      final s = slug(value);
      if (s.isEmpty || candidates.contains(s)) return;
      candidates.add(s);
    }

    final raw = recipientName ?? '';
    add(brandCanonicalSlug(raw, labelType, direction));
    add(vpaLocalPart(upiId));
    add(raw);
    return candidates;
  }
}
