import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/home/presentation/widgets/balance_hero.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          if (state is TransactionInitial || state is TransactionLoading) {
            return _buildLoading();
          } else if (state is TransactionLoaded) {
            if (state.transactions.isEmpty) {
              return _buildEmpty(state.currentBalance ?? 0.0);
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

  Widget _buildLoading() {
    return Column(
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
    );
  }

  Widget _buildEmpty(double balance) {
    return Column(
      children: [
        BalanceHero(balance: balance),
        const Expanded(child: EmptyState()),
      ],
    );
  }

  Widget _buildLoaded(BuildContext context, List<Transaction> transactions, double balance) {
    final grouped = _groupTransactions(transactions);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: BalanceHero(balance: balance)),
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
