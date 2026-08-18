import 'package:equatable/equatable.dart';

/// One detected sender of money in a month, with its resolved display name.
class ResolvedSender extends Equatable {
  /// Normalized identity key (lowercased VPA / name, e.g. "kk9396@okhdfcbank").
  final String key;

  /// Original sender string from the SMS, title-cased.
  final String rawName;

  /// The name shown to the user: label → contact name → [rawName].
  final String displayName;

  /// True when a user label or a contact match identified this sender.
  final bool identified;

  /// How this sender was identified: 'label' (named by the user), 'contact'
  /// (matched to the address book), or null (raw SMS name / unidentified).
  final String? identification;

  final double amount;
  final int count;

  const ResolvedSender({
    required this.key,
    required this.rawName,
    required this.displayName,
    required this.identified,
    this.identification,
    required this.amount,
    required this.count,
  });

  @override
  List<Object?> get props =>
      [key, rawName, displayName, identified, identification, amount, count];
}
