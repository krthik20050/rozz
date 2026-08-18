import 'package:equatable/equatable.dart';

/// A user-defined identity for a sender: the normalized key (UPI ID / VPA /
/// phone digits) maps to a human label like "father".
class SenderLabel extends Equatable {
  final String key;
  final String label;

  const SenderLabel({required this.key, required this.label});

  @override
  List<Object?> get props => [key, label];
}
