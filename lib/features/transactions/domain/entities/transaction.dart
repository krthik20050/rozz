import 'package:equatable/equatable.dart';

class Transaction extends Equatable {
  final int? id;
  final String date; // ISO 8601 UTC
  final double amount;
  final String direction; // 'debit' | 'credit'
  final String labelType;
  final String? recipientName;
  final String? upiId;
  final double? balanceAfter;
  final String source;
  final String? upiRefNumber;
  final String? rawSms;
  final String? category; // Added for AI categorization

  /// Canonical merchant key ("the central ID") this payment resolves to, e.g.
  /// 'swiggy' or a slugged person/merchant name. Null until an alias or brand
  /// match links it.
  final String? merchantKey;

  /// The user's own description for this payment ("dinner", "rent"). Copied
  /// automatically from the merchant profile when unambiguous — the user's
  /// word wins over every other name in the UI.
  final String? userNarration;

  const Transaction({
    this.id,
    required this.date,
    required this.amount,
    required this.direction,
    required this.labelType,
    this.recipientName,
    this.upiId,
    this.balanceAfter,
    required this.source,
    this.upiRefNumber,
    this.rawSms,
    this.category,
    this.merchantKey,
    this.userNarration,
  });

  @override
  List<Object?> get props => [
        id,
        date,
        amount,
        direction,
        labelType,
        recipientName,
        upiId,
        balanceAfter,
        source,
        upiRefNumber,
        rawSms,
        category,
        merchantKey,
        userNarration,
      ];
}