import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/shared/widgets/skeleton.dart';

/// Skeleton for the balance hero: greeting, name, balance number, subtitle.
class BalanceHeroSkeleton extends StatelessWidget {
  const BalanceHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 90, height: 12),
                  SizedBox(height: 8),
                  SkeletonLine(width: 120, height: 20),
                ],
              ),
              SkeletonCircle(size: 40),
            ],
          ),
          SizedBox(height: 24),
          SkeletonLine(width: 220, height: 40),
          SizedBox(height: 12),
          SkeletonLine(width: 200, height: 12),
        ],
      ),
    );
  }
}

/// Skeleton for one transaction row, mirroring TransactionCard.
class TransactionCardSkeleton extends StatelessWidget {
  const TransactionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RozzColors.cardBorder),
      ),
      child: const Row(
        children: [
          SkeletonCircle(size: 44),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(width: 120, height: 14),
                SizedBox(height: 8),
                SkeletonLine(width: 160, height: 12),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonLine(width: 60, height: 14),
        ],
      ),
    );
  }
}

/// Skeleton for the upcoming-charges card, mirroring UpcomingChargesCard.
class UpcomingChargesSkeleton extends StatelessWidget {
  const UpcomingChargesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RozzColors.cardBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLine(width: 140, height: 11),
          SizedBox(height: 16),
          _UpcomingRowSkeleton(),
          _UpcomingRowSkeleton(),
          _UpcomingRowSkeleton(),
        ],
      ),
    );
  }
}

class _UpcomingRowSkeleton extends StatelessWidget {
  const _UpcomingRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SkeletonCircle(size: 36),
          SizedBox(width: 14),
          Expanded(child: SkeletonLine(width: 110, height: 13)),
          SizedBox(width: 12),
          SkeletonLine(width: 50, height: 13),
          SizedBox(width: 16),
          SkeletonLine(width: 44, height: 11),
        ],
      ),
    );
  }
}

/// The home page's first-load skeleton: hero + upcoming charges + a list of
/// transaction rows, each shimmering.
class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          const Shimmer(child: BalanceHeroSkeleton()),
          const Shimmer(child: UpcomingChargesSkeleton()),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: const Shimmer(
              child: Column(
                children: [
                  SkeletonLine(width: 160, height: 11),
                  SizedBox(height: 12),
                ],
              ),
            ),
          ),
          for (var i = 0; i < 5; i++)
            const Shimmer(child: TransactionCardSkeleton()),
        ],
      ),
    );
  }
}
