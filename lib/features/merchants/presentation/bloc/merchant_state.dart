part of 'merchant_bloc.dart';

abstract class MerchantState extends Equatable {
  const MerchantState();

  @override
  List<Object?> get props => [];
}

class MerchantInitial extends MerchantState {}

class MerchantLoading extends MerchantState {}

class MerchantLoaded extends MerchantState {
  final List<Merchant> merchants;

  /// Last description write (rows changed / conflict), cleared on load —
  /// lets the shell refresh the transaction list right after propagation.
  final DescriptionApply? lastApply;

  const MerchantLoaded({required this.merchants, this.lastApply});

  Map<String, Merchant> get byKey =>
      {for (final m in merchants) m.merchantKey: m};

  @override
  List<Object?> get props => [merchants, lastApply];
}

class MerchantError extends MerchantState {
  final String message;

  const MerchantError(this.message);

  @override
  List<Object?> get props => [message];
}
