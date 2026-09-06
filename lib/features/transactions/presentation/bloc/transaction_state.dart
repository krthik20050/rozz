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

  /// Day (yyyy-MM-dd) of the bank anchor behind [currentBalance] — the UI
  /// shows an "as of 3 Aug" freshness line when it is older than today, so
  /// a replayed-over anchor can never silently look current.
  final String? anchoredOn;

  /// How many ledger transactions were replayed on top of the anchor.
  final int replayedTransactions;

  const TransactionLoaded(
    this.transactions,
    this.currentBalance, {
    this.bankVerified = false,
    this.anchoredOn,
    this.replayedTransactions = 0,
  });

  @override
  List<Object?> get props =>
      [transactions, currentBalance, bankVerified, anchoredOn, replayedTransactions];
}

class TransactionError extends TransactionState {
  final String message;

  const TransactionError(this.message);

  @override
  List<Object?> get props => [message];
}
