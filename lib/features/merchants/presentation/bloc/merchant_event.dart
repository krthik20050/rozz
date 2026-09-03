part of 'merchant_bloc.dart';

abstract class MerchantEvent extends Equatable {
  const MerchantEvent();

  @override
  List<Object?> get props => [];
}

/// Full refresh of the merchant list.
class LoadMerchants extends MerchantEvent {}

/// Describe (or re-describe) a payee. [merchantWide] == false is the
/// transaction-level flow from a payment's details sheet: the described
/// payment always adopts the word, and so do the payee's other payments that
/// have no description of their own — never a conflicting purpose. With
/// [merchantWide] == true (manage-payees edit) every payment of the payee is
/// renamed deliberately. [recipientName]/[upiId] seed the alias store so
/// future SMS/statement rows resolve to the same merchant.
class SaveMerchantDescription extends MerchantEvent {
  final String merchantKey;
  final String canonicalName;
  final String description;
  final bool merchantWide;
  final int? triggerTxId;
  final String? recipientName;
  final String? upiId;
  final String? labelType;

  const SaveMerchantDescription({
    required this.merchantKey,
    required this.canonicalName,
    required this.description,
    this.merchantWide = false,
    this.triggerTxId,
    this.recipientName,
    this.upiId,
    this.labelType,
  });

  @override
  List<Object?> get props => [
        merchantKey,
        canonicalName,
        description,
        merchantWide,
        triggerTxId,
        recipientName,
        upiId,
        labelType,
      ];
}

/// Remove the payee's description and strip its propagated copies.
class ClearMerchantDescription extends MerchantEvent {
  final String merchantKey;

  const ClearMerchantDescription(this.merchantKey);

  @override
  List<Object?> get props => [merchantKey];
}
