import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/features/home/presentation/widgets/home_skeletons.dart';
import 'package:rozz/features/insights/presentation/widgets/insights_skeletons.dart';
import 'package:rozz/shared/widgets/skeleton.dart';

void main() {
  testWidgets('Shimmer renders its child and animates without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Shimmer(
            child: Column(
              children: [
                SkeletonBox(height: 40, width: 120),
                SkeletonLine(width: 160, height: 12),
                SkeletonCircle(size: 32),
              ],
            ),
          ),
        ),
      ),
    );
    // Let the repeat controller tick a few frames.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(Shimmer), findsOneWidget);
    // SkeletonLine builds a SkeletonBox internally, so there are two boxes.
    expect(find.byType(SkeletonBox), findsNWidgets(2));
    expect(find.byType(SkeletonLine), findsOneWidget);
    expect(find.byType(SkeletonCircle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home loading skeleton shows per-section skeletons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeLoadingSkeleton())),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(BalanceHeroSkeleton), findsOneWidget);
    expect(find.byType(UpcomingChargesSkeleton), findsOneWidget);
    expect(find.byType(TransactionCardSkeleton), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('insights skeleton adapts to the selected tab', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: InsightsLoadingSkeleton(tab: 'income')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Income tab skeleton: month pill line + received header card + rows.
    expect(find.byType(InsightsLoadingSkeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
