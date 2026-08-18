import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/shared/widgets/skeleton.dart';

/// Skeleton for the insights page, shaped per selected tab so the loading
/// state previews the layout that is coming.
class InsightsLoadingSkeleton extends StatelessWidget {
  final String tab;

  const InsightsLoadingSkeleton({super.key, required this.tab});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: switch (tab) {
        'for you' => const _ForYouSkeleton(),
        'spending' => const _SpendingSkeleton(),
        'subscriptions' => const _SubscriptionsSkeleton(),
        'income' => const _IncomeSkeleton(),
        _ => const _ForYouSkeleton(),
      },
    );
  }
}

/// Month pill + three stat boxes + a few full cards (health banner, streak,
/// spending highlight) — mirrors ForYouTab.
class _ForYouSkeleton extends StatelessWidget {
  const _ForYouSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonLine(width: 100, height: 26),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: SkeletonBox(height: 84)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 84)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 84)),
          ],
        ),
        const SizedBox(height: 16),
        const _FullSkeletonCard(height: 92),
        const SizedBox(height: 12),
        const _FullSkeletonCard(height: 92),
        const SizedBox(height: 12),
        const _FullSkeletonCard(height: 140),
      ],
    );
  }
}

/// Total header + ranked category rows — mirrors SpendingTab.
class _SpendingSkeleton extends StatelessWidget {
  const _SpendingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonLine(width: 100, height: 26),
        const SizedBox(height: 12),
        const _FullSkeletonCard(height: 110),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) ...[          
          SkeletonBox(
            height: 92,
            borderRadius: BorderRadius.circular(16),
          ),
          if (i < 3) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Total header + subscription rows — mirrors SubscriptionsTab.
class _SubscriptionsSkeleton extends StatelessWidget {
  const _SubscriptionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,      children: [
        const _FullSkeletonCard(height: 110),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) ...[          
          const _FullSkeletonCard(height: 72),
          if (i < 3) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Received header + income source rows — mirrors IncomeTab.
class _IncomeSkeleton extends StatelessWidget {
  const _IncomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [        const SkeletonLine(width: 100, height: 26),
        const SizedBox(height: 12),
        const _FullSkeletonCard(height: 110),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) ...[          
          const _FullSkeletonCard(height: 72),
          if (i < 3) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// A full-width card-shaped skeleton block matching the app's card chrome.
class _FullSkeletonCard extends StatelessWidget {
  final double height;

  const _FullSkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RozzColors.cardBorder),
      ),
    );
  }
}
