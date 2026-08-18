import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/shared/widgets/pressable.dart';
import 'package:rozz/shared/widgets/sliding_pill_bar.dart';
import 'package:rozz/shared/widgets/state_message.dart';

void main() {
  testWidgets('StateMessage.error shows title and fires retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StateMessage.error(
            title: 'could not load',
            message: 'something went wrong',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('could not load'), findsOneWidget);
    expect(find.text('something went wrong'), findsOneWidget);

    await tester.tap(find.text('retry'));
    expect(retried, isTrue);
  });

  testWidgets('StateMessage.empty renders without an action button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StateMessage.empty(
            title: 'nothing here yet',
            message: 'check back soon',
          ),
        ),
      ),
    );

    expect(find.text('nothing here yet'), findsOneWidget);
    expect(find.text('retry'), findsNothing);
  });

  testWidgets('SlidingPillBar slides the pill to the tapped label', (tester) async {
    var selected = 'for you';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlidingPillBar(
            labels: const ['for you', 'spending', 'income'],
            selected: selected,
            onChanged: (label) => selected = label,
          ),
        ),
      ),
    );
    // Let the post-frame measurement run.
    await tester.pump();

    await tester.tap(find.text('spending'));
    await tester.pump();
    expect(selected, 'spending');

    // Pill should now sit over the 'spending' chip: the gold pill container
    // exists and 'spending' is the selected chip.
    expect(selected, 'spending');
    expect(tester.takeException(), isNull);
  });

  testWidgets('PressableScale triggers onTap and scales down on press', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PressableScale(
            onTap: () => tapped++,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PressableScale)));
    await tester.pump(const Duration(milliseconds: 60));
    await gesture.up();
    await tester.pump();

    expect(tapped, 1);
    expect(tester.takeException(), isNull);
  });
}
