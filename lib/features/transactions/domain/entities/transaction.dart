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
  final String? category;

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
      ];
}
