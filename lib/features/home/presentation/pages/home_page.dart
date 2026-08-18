import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/home/presentation/widgets/balance_hero.dart';
import 'package:rozz/features/home/presentation/widgets/home_skeletons.dart';
import 'package:rozz/features/home/presentation/widgets/upcoming_charges_card.dart';
import 'package:rozz/features/insights/presentation/bloc/insights_bloc.dart';
import 'package:rozz/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:rozz/features/transactions/presentation/widgets/transaction_card.dart';
import 'package:rozz/features/transactions/presentation/widgets/transaction_details_sheet.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/shared/widgets/state_message.dart';

class HomePage extends StatelessWidget {
  final VoidCallback onSync;

  /// Last 4 digits of the real account number (from the bank SMS).
  final String? accountSuffix;

  /// Whether the app has notification-access permission (bank SMS capture).
  final bool notificationAccess;

  /// Callback to open the notification-access onboarding.
  final VoidCallback? onEnableNotificationAccess;

  const HomePage({
    super.key,
    required this.onSync,
    this.accountSuffix,
    this.notificationAccess = true,
    this.onEnableNotificationAccess,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      body: SafeArea(
        child: BlocBuilder<TransactionBloc, TransactionState>(
          builder: (context, state) {
            if (state is TransactionInitial || state is TransactionLoading) {
              return _buildLoading(context);
            } else if (state is TransactionLoaded) {
              if (state.transactions.isEmpty) {
                return _buildEmpty(context, state.currentBalance ?? 0.0);
              }
              return _buildLoaded(context, state.transactions, state.currentBalance ?? 0.0);
            } else if (state is TransactionError) {
              return StateMessage.error(
                title: 'couldn\'t load your account',
                message: 'Something went wrong while reading your transactions. Your data stays on your phone — try again.',
                onRetry: () => context.read<TransactionBloc>().add(LoadTransactions()),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return const HomeLoadingSkeleton();
  }

  Widget _buildEmpty(BuildContext context, double balance) {
    return Column(
      children: [
        BalanceHero(balance: balance, accountSuffix: accountSuffix),
        const Expanded(
          child: StateMessage.empty(
            title: 'no transactions yet',
            message: 'your bank SMS will appear here as soon as it\'s synced.',
          ),
        ),
        Column(
          children: [
            if (!notificationAccess)
              Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RozzColors.s2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: RozzColors.gold.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_off_outlined,
                      color: RozzColors.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ROZZ can\'t hear your bank SMS yet. Enable notification access so new transactions arrive automatically.',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          height: 1.4,
                          color: RozzColors.textSecondary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onEnableNotificationAccess,
                      style: TextButton.styleFrom(
                        foregroundColor: RozzColors.gold,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        'enable',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            TextButton(
              onPressed: onSync,
              style: TextButton.styleFrom(foregroundColor: RozzColors.gold),
              child: Text(
                'sync now',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoaded(BuildContext context, List<Transaction> transactions, double balance) {
    final recentTxns = transactions.take(5).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: BalanceHero(
            balance: balance,
            accountSuffix: accountSuffix,
          ),
        ),
        SliverToBoxAdapter(
          child: BlocBuilder<InsightsBloc, InsightsState>(
            builder: (context, state) {
              if (state is InsightsLoading || state is InsightsInitial) {
                // Progressive: the upcoming-charges block loads on its own
                // timeline, showing a skeleton until insights resolve.
                return const UpcomingChargesSkeleton();
              }
              if (state is! InsightsLoaded) return const SizedBox.shrink();
              return UpcomingChargesCard(charges: state.upcomingCharges);
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT TRANSACTIONS',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: RozzColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'view all',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: RozzColors.gold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final tx = recentTxns[index];
                return TransactionCard(
                  transaction: tx,
                  onTap: () => TransactionDetailsSheet.show(context, tx),
                );
              },
              childCount: recentTxns.length,
            ),
          ),
        ),
      ],
    );
  }
}
