import 'package:rozz/features/transactions/domain/entities/transaction.dart';

class TransactionModel extends Transaction {
  const TransactionModel({
    super.id,
    required super.date,
    required super.amount,
    required super.direction,
    required super.labelType,
    super.recipientName,
    super.upiId,
    super.balanceAfter,
    required super.source,
    super.upiRefNumber,
    super.rawSms,
    super.category,
  });

  factory TransactionModel.fromSms(Map<String, dynamic> parsed, String rawSms) {
    return TransactionModel(
      date: parsed['date'] ?? DateTime.now().toUtc().toIso8601String(),
      amount: (parsed['amount'] as num).toDouble(),
      direction: parsed['direction'] as String,
      labelType: parsed['label_type'] as String? ?? 'unknown',
      recipientName: parsed['recipient_name'] as String?,
      upiId: parsed['upi_id'] as String?,
      balanceAfter: parsed['balance_after'] != null
          ? (parsed['balance_after'] as num).toDouble()
          : null,
      source: 'sms',
      upiRefNumber: parsed['upi_ref_number'] as String?,
      rawSms: rawSms,
      category: parsed['category'] as String?,
    );
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      date: map['date'] as String,
      amount: (map['amount'] as num).toDouble(),
      direction: map['direction'] as String,
      labelType: map['label_type'] as String,
      recipientName: map['recipient_name'] as String?,
      upiId: map['upi_id'] as String?,
      balanceAfter: map['balance_after'] != null
          ? (map['balance_after'] as num).toDouble()
          : null,
      source: map['source'] as String,
      upiRefNumber: map['upi_ref_number'] as String?,
      rawSms: map['raw_sms'] as String?,
      category: map['category'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'amount': amount,
      'direction': direction,
      'label_type': labelType,
      'recipient_name': recipientName,
      'upi_id': upiId,
      'balance_after': balanceAfter,
      'source': source,
      'upi_ref_number': upiRefNumber,
      'raw_sms': rawSms,
      'category': category,
    };
  }
}