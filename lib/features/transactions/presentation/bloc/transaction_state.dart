part of 'transaction_bloc.dart';

abstract class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object?> get props => [];
}

class TransactionInitial extends TransactionState {}

class TransactionLoading extends TransactionState {}

class TransactionLoaded extends TransactionState {
  final List<Transaction> transactions;
  final double? currentBalance;

  /// True when [currentBalance] is anchored on a bank-reported balance
  /// (newest bank balance + replayed ledger deltas). False when no bank
  /// balance has ever been seen — the UI must then NOT present the number
  /// as the bank balance (it is null in that case anyway).
  final bool bankVerified;

  const TransactionLoaded(
    this.transactions,
    this.currentBalance, {
    this.bankVerified = false,
  });

  @override
  List<Object?> get props => [transactions, currentBalance, bankVerified];
}

class TransactionError extends TransactionState {
  final String message;

  const TransactionError(this.message);

  @override
  List<Object?> get props => [message];
}
