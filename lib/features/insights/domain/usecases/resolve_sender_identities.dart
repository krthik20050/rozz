import 'package:rozz/features/insights/domain/entities/income_source.dart';
import 'package:rozz/features/insights/domain/entities/resolved_sender.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/shared/utils/phone_normalizer.dart';
import 'package:rozz/shared/utils/sender_label_resolver.dart';

/// The result of resolving a month's credit transactions into senders.
class ResolvedIncome {
  /// One entry per distinct sender key (for the manage-senders screen).
  final List<ResolvedSender> senders;

  /// Senders merged by display name, largest first (for the income tab).
  final List<IncomeSource> incomeSources;

  const ResolvedIncome({required this.senders, required this.incomeSources});
}

/// Identifies who sent money this month.
///
/// Pure: takes credit transactions plus two lookup tables and returns
/// per-sender rows + identity-merged income sources. Resolution order for a
/// sender's display name:
///   1. user label on the sender key (or its VPA local-part), e.g.
///      "kk9396@okhdfcbank" → "father";
///   2. user label whose stem (the distinctive part, e.g. "kknair") appears
///      in the key — so labeling "kknair9396@ybl" as "papa" also names
///      "kknair1967@ybl" and "kknair1967@axl" (same person, different VPAs);
///   3. contact match: a 10-digit phone number inside the sender string
///      matches a normalized contact phone number → the contact's name;
///   4. fallback: the raw sender name, title-cased.
class ResolveSenderIdentities {
  /// [labels] maps a normalized sender key (or VPA local-part) to a label.
  /// [contactPhoneToName] maps a 10-digit phone to a contact name.
  ResolvedIncome call({
    required List<Transaction> transactions,
    required Map<String, String> labels,
    required Map<String, String> contactPhoneToName,
  }) {
    final byKey = <String, List<Transaction>>{};
    for (final tx in transactions) {
      if (tx.direction != 'credit') continue;
      final key = _normalize(tx.recipientName);
      if (key.isEmpty) continue;
      byKey.putIfAbsent(key, () => []).add(tx);
    }

    final senders = <ResolvedSender>[];
    byKey.forEach((key, txs) {
      final total = txs.fold(0.0, (sum, tx) => sum + tx.amount);
      final rawName = _titleCase(txs.first.recipientName);
      final label = resolveSenderLabel(key, labels);
      final contactName = _contactFor(key, contactPhoneToName);
      final identification =
          label != null ? 'label' : (contactName != null ? 'contact' : null);
      senders.add(ResolvedSender(
        key: key,
        rawName: rawName,
        displayName: label ?? contactName ?? rawName,
        identified: identification != null,
        identification: identification,
        amount: total,
        count: txs.length,
      ));
    });
    senders.sort((a, b) => b.amount.compareTo(a.amount));

    // Merge rows that resolve to the same display name — father's two VPAs
    // both labeled "father" become one "father" row on the income tab.
    final byDisplay = <String, List<ResolvedSender>>{};
    for (final s in senders) {
      byDisplay.putIfAbsent(s.displayName, () => []).add(s);
    }
    final incomeSources = byDisplay.entries
        .map((e) => IncomeSource(
              recipient: e.key,
              amount: e.value.fold(0.0, (sum, s) => sum + s.amount),
              count: e.value.fold(0, (sum, s) => sum + s.count),
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return ResolvedIncome(senders: senders, incomeSources: incomeSources);
  }

  String _normalize(String? name) {
    return (name?.trim() ?? '').toLowerCase();
  }

  String _titleCase(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return 'Unknown';
    return trimmed
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Every plausible 10-digit phone number inside the sender string, checked
  /// against the contact book — so "9855343141-2@ybl" matches the contact
  /// stored as "9855343141".
  String? _contactFor(String key, Map<String, String> contactPhoneToName) {
    if (contactPhoneToName.isEmpty) return null;
    for (final candidate in phoneCandidates(key)) {
      final name = contactPhoneToName[candidate];
      if (name != null) return name;
    }
    return null;
  }
}
