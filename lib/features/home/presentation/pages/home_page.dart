import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/home/presentation/widgets/balance_hero.dart';
import 'package:rozz/features/onboarding/presentation/pages/settings_page.dart';
import 'package:rozz/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:rozz/features/transactions/presentation/widgets/transaction_card.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/shared/widgets/shimmer_card.dart';
import 'package:rozz/shared/widgets/empty_state.dart';
import 'package:rozz/shared/widgets/error_state.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  double _computeTodaySpend(List<Transaction> transactions) {
    final todayFormatter = DateFormat('yyyy-MM-dd');
    final todayStr = todayFormatter.format(DateTime.now());
    return transactions
        .where((tx) {
          final dateStr = todayFormatter.format(DateTime.parse(tx.date).toLocal());
          return dateStr == todayStr && tx.direction == 'debit';
        })
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          if (state is TransactionInitial || state is TransactionLoading) {
            return _buildLoading(context);
          } else if (state is TransactionLoaded) {
            if (state.transactions.isEmpty) {
              return _buildEmpty(context, state.currentBalance ?? 0.0);
            }
            return _buildLoaded(context, state.transactions, state.currentBalance ?? 0.0);
          } else if (state is TransactionError) {
            return ErrorState(message: state.message);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.settings_outlined, color: RozzColors.textSecondary),
            tooltip: 'Settings',
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            const BalanceHero(balance: 0.0),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: 5,
                itemBuilder: (context, index) => const ShimmerCard(),
              ),
            ),
          ],
        ),
        _buildSettingsButton(context),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context, double balance) {
    return Stack(
      children: [
        Column(
          children: [
            BalanceHero(balance: balance),
            const Expanded(child: EmptyState()),
          ],
        ),
        _buildSettingsButton(context),
      ],
    );
  }

  Widget _buildLoaded(BuildContext context, List<Transaction> transactions, double balance) {
    final grouped = _groupTransactions(transactions);
    final todaySpend = _computeTodaySpend(transactions);

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: BalanceHero(balance: balance, todaySpend: todaySpend)),
            ...grouped.entries.map((entry) {
              return SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Text(
                        entry.key,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: RozzColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return TransactionCard(
                            transaction: entry.value[index],
                            onTap: () {
                              // TODO: Navigate to details
                            },
                          );
                        },
                        childCount: entry.value.length,
                      ),
                    ),
                  ),
                ],
              );
            }),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
        _buildSettingsButton(context),
      ],
    );
  }

  Map<String, List<Transaction>> _groupTransactions(List<Transaction> transactions) {
    final Map<String, List<Transaction>> grouped = {};
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    for (var tx in transactions) {
      final date = DateTime.parse(tx.date).toLocal();
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      String header;
      if (dateStr == todayStr) {
        header = 'TODAY';
      } else if (dateStr == yesterdayStr) {
        header = 'YESTERDAY';
      } else {
        header = DateFormat('dd MMM yyyy').format(date).toUpperCase();
      }

      if (grouped[header] == null) {
        grouped[header] = [];
      }
      grouped[header]!.add(tx);
    }
    return grouped;
  }
}
