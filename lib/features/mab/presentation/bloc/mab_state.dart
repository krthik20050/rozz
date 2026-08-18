part of 'mab_bloc.dart';

abstract class MabState extends Equatable {
  const MabState();

  @override
  List<Object?> get props => [];
}

class MabInitial extends MabState {}

class MabLoading extends MabState {}

class MabLoaded extends MabState {
  final MabStatus status;
  final List<MabRecord> records;

  /// The month this forecast was computed for — the page shows it (real data,
  /// never a hardcoded label) and lets the user switch months.
  final int month;
  final int year;

  const MabLoaded(
    this.status, [
    this.records = const [],
    this.month = 0,
    this.year = 0,
  ]) : super();

  @override
  List<Object?> get props => [status, records, month, year];
}

class MabError extends MabState {
  final String message;

  const MabError(this.message);

  @override
  List<Object?> get props => [message];
}
