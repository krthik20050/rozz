import 'package:equatable/equatable.dart';

/// One canonical payee — the "central ID" that raw spellings of a merchant
/// resolve to (SWIGGY / Swiggy India / swiggy@ybl -> key `swiggy`).
class Merchant extends Equatable {
  /// Slug key, e.g. 'swiggy' or 'rahulverma'.
  final String merchantKey;

  /// Human display name for the payee ("Swiggy", "Rahul Verma").
  final String canonicalName;

  final String? category;

  /// The user's canonical description ("dinner"). Null until the user (or an
  /// unambiguous AI cluster) names the purpose of payments to this payee.
  final String? description;

  /// 'brand' | 'ai' | 'user' | 'statement'
  final String source;

  /// 1 when the user gave two DIFFERENT descriptions for the same merchant —
  /// auto-apply stops and the UI asks instead of guessing.
  final bool conflict;

  /// Debit payment count currently linked to this merchant.
  final int txCount;

  /// Total debited to this merchant across the ledger.
  final double totalAmount;

  /// ISO date of the newest linked payment.
  final String? lastSeen;

  const Merchant({
    required this.merchantKey,
    required this.canonicalName,
    this.category,
    this.description,
    required this.source,
    this.conflict = false,
    this.txCount = 0,
    this.totalAmount = 0,
    this.lastSeen,
  });

  @override
  List<Object?> get props => [
        merchantKey,
        canonicalName,
        category,
        description,
        source,
        conflict,
        txCount,
        totalAmount,
        lastSeen,
      ];
}
