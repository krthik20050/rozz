import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/security/clipboard_guard.dart';

void main() {
  setUpAll(() => WidgetsFlutterBinding.ensureInitialized());

  group('ClipboardGuard', () {
    test('recognises financial clipboard content', () {
      expect(ClipboardGuard.isFinancialText('paid Rs. 1,500 via UPI'), isTrue);
      expect(ClipboardGuard.isFinancialText('INR 2,000 debited from A/c'), isTrue);
      expect(ClipboardGuard.isFinancialText('₹ balance is 4,732.10'), isTrue);
    });

    test('ignores ordinary text and emails', () {
      expect(ClipboardGuard.isFinancialText('hello@example.com'), isFalse);
      expect(ClipboardGuard.isFinancialText('my preferences for the accordion concert'), isFalse);
      expect(ClipboardGuard.isFinancialText('refer a friend, get 10% off'), isFalse);
    });
  });
}