import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/main.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(RozzApp(smsParser: SmsParser()));

    // Verify that our counter starts at 0.
    // Note: ROZZ doesn't have the counter anymore, but we'll check for "ROZZ" text
    expect(find.text('ROZZ'), findsOneWidget);
  });
}
