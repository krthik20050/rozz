import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/features/insights/domain/usecases/resolve_sender_identities.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';

void main() {
  final resolve = ResolveSenderIdentities();

  TransactionModel credit({required double amount, required String from}) {
    return TransactionModel(
      date: '2026-08-01',
      amount: amount,
      direction: 'credit',
      labelType: 'upi',
      recipientName: from,
      source: 'sms',
    );
  }

  test('exact key and VPA local-part labels still resolve', () {
    final resolved = resolve(
      transactions: [credit(amount: 2000, from: 'kk9396@okhdfcbank')],
      labels: const {'kk9396': 'father'},
      contactPhoneToName: const {},
    );

    expect(resolved.senders.single.displayName, 'father');
    expect(resolved.senders.single.identification, 'label');
  });

  test('a label on one VPA names the same person on other VPAs (kknair → papa)', () {
    final resolved = resolve(
      transactions: [
        credit(amount: 1000, from: 'kknair1967@ybl'),
        credit(amount: 1500, from: 'kknair1967@axl'),
        credit(amount: 2000, from: 'kknair9396@ybl'),
      ],
      // Only the 9396 VPA was labeled — the stem "kknair" carries the rest.
      labels: const {'kknair9396@ybl': 'papa'},
      contactPhoneToName: const {},
    );

    final byKey = {for (final s in resolved.senders) s.key: s};
    expect(byKey['kknair1967@ybl']!.displayName, 'papa');
    expect(byKey['kknair1967@axl']!.displayName, 'papa');
    expect(byKey['kknair9396@ybl']!.displayName, 'papa');
    // And they merge into a single "papa" income source.
    expect(resolved.incomeSources.single.recipient, 'papa');
    expect(resolved.incomeSources.single.amount, 4500);
  });

  test('stems do not leak across unrelated PSP suffixes', () {
    final resolved = resolve(
      transactions: [credit(amount: 500, from: 'someotherguy@ybl')],
      labels: const {'kknair9396@ybl': 'papa'},
      contactPhoneToName: const {},
    );

    // "ybl" is a PSP handle, never a stem — no false "papa".
    expect(resolved.senders.single.displayName, 'Someotherguy@ybl');
    expect(resolved.senders.single.identified, isFalse);
  });

  test('contact match works for a phone buried in a VPA with a suffix', () {
    final resolved = resolve(
      transactions: [credit(amount: 700, from: '9855343141-2@ybl')],
      labels: const {},
      contactPhoneToName: const {'9855343141': 'Jagan'},
    );

    expect(resolved.senders.single.displayName, 'Jagan');
    expect(resolved.senders.single.identification, 'contact');
  });

  test('unidentified senders fall back to the raw title-cased name', () {
    final resolved = resolve(
      transactions: [credit(amount: 300, from: 'gokulnenmini212@okaxis')],
      labels: const {},
      contactPhoneToName: const {},
    );

    expect(resolved.senders.single.displayName, 'Gokulnenmini212@okaxis');
    expect(resolved.senders.single.identified, isFalse);
  });
}
