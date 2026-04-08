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

  MabLoaded(this.status, [this.records = const []]);

  @override
  List<Object?> get props => [status];
}

class MabError extends MabState {
  final String message;

  const MabError(this.message);

  @override
  List<Object?> get props => [message];
}
