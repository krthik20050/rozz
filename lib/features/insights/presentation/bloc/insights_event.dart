part of 'insights_bloc.dart';

abstract class InsightsEvent extends Equatable {
  const InsightsEvent();

  @override
  List<Object?> get props => [];
}

class LoadInsights extends InsightsEvent {
  final DateTime? now;

  const LoadInsights({this.now});

  @override
  List<Object?> get props => [now];
}

class SaveSenderLabel extends InsightsEvent {
  final String key;
  final String label;
  final DateTime? now;

  const SaveSenderLabel({required this.key, required this.label, this.now});

  @override
  List<Object?> get props => [key, label, now];
}

class DeleteSenderLabel extends InsightsEvent {
  final String key;
  final DateTime? now;

  const DeleteSenderLabel({required this.key, this.now});

  @override
  List<Object?> get props => [key, now];
}

/// Re-run the contacts lookup (the user may have just granted permission) and
/// refresh the loaded insights so unidentified senders get another chance to
/// match a contact name.
class CheckContacts extends InsightsEvent {
  final DateTime? now;

  const CheckContacts({this.now});

  @override
  List<Object?> get props => [now];
}

/// Hide a detected subscription forever (a monthly haircut, a local merchant).
class DismissSubscription extends InsightsEvent {
  final String merchantKey;
  final DateTime? now;

  const DismissSubscription({required this.merchantKey, this.now});

  @override
  List<Object?> get props => [merchantKey, now];
}

/// Bring a dismissed subscription back into the list.
class RestoreSubscription extends InsightsEvent {
  final String merchantKey;
  final DateTime? now;

  const RestoreSubscription({required this.merchantKey, this.now});

  @override
  List<Object?> get props => [merchantKey, now];
}
