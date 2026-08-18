import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:rozz/features/transactions/presentation/widgets/transaction_card.dart';
import 'package:rozz/features/transactions/presentation/widgets/transaction_details_sheet.dart';
import 'package:rozz/features/home/presentation/widgets/home_skeletons.dart';
import 'package:rozz/shared/widgets/skeleton.dart';
import 'package:rozz/shared/widgets/sliding_pill_bar.dart';
import 'package:rozz/shared/widgets/state_message.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  String _selectedFilter = 'all'; // 'all', 'money in', 'money out'
  String _searchQuery = '';
  bool _oldestFirst = false;

  Future<void> _openSearch() async {
    final controller = TextEditingController(text: _searchQuery);
    final query = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: RozzColors.s2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'search transactions',
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: RozzColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'matches merchant, category or sender name',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: RozzColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: RozzColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. swiggy, father, upi',
                  hintStyle: const TextStyle(color: RozzColors.textMuted),
                  prefixIcon: const Icon(Icons.search, color: RozzColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: RozzColors.s3,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (value) => Navigator.of(sheetContext).pop(value.trim()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(controller.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RozzColors.gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'search',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (query != null && mounted) {
      setState(() => _searchQuery = query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'activity',
                    style: GoogleFonts.syne(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: RozzColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _openSearch,
                        icon: const Icon(Icons.search, color: RozzColors.textSecondary),
                        tooltip: 'search',
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() => _oldestFirst = !_oldestFirst);
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: RozzColors.s2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                content: Text(
                                  _oldestFirst ? 'sorted: oldest first' : 'sorted: newest first',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: RozzColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                        },
                        icon: const Icon(Icons.tune, color: RozzColors.textSecondary),
                        tooltip: 'sort order',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Filter Chips Bar — the gold pill slides to the active filter.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: SlidingPillBar(
                labels: const ['all', 'money in', 'money out'],
                selected: _selectedFilter,
                onChanged: (label) => setState(() => _selectedFilter = label),
              ),
            ),

            const SizedBox(height: 12),

            // Main Transaction List
            Expanded(
              child: BlocBuilder<TransactionBloc, TransactionState>(
                builder: (context, state) {
                  if (state is TransactionInitial || state is TransactionLoading) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: 6,
                      itemBuilder: (context, index) =>
                          const Shimmer(child: TransactionCardSkeleton()),
                    );
                  } else if (state is TransactionLoaded) {
                    final filtered = _filterTransactions(state.transactions);
                    if (filtered.isEmpty) {
                      return const StateMessage.empty(
                        title: 'nothing here yet',
                        message: 'no transactions match this filter.',
                      );
                    }
                    return _buildTransactionList(context, filtered);
                  } else if (state is TransactionError) {
                    return StateMessage.error(
                      title: 'couldn\'t load your activity',
                      message: 'Something went wrong while reading your transactions. Try again.',
                      onRetry: () => context.read<TransactionBloc>().add(LoadTransactions()),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Transaction> _filterTransactions(List<Transaction> list) {
    var result = list;
    if (_selectedFilter == 'money in') {
      result = result.where((t) => t.direction == 'credit').toList();
    } else if (_selectedFilter == 'money out') {
      result = result.where((t) => t.direction == 'debit').toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((t) =>
              (t.recipientName?.toLowerCase().contains(q) ?? false) ||
              (t.category?.toLowerCase().contains(q) ?? false) ||
              (t.upiId?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    if (_oldestFirst) {
      result = [...result]..sort((a, b) => a.date.compareTo(b.date));
    }
    return result;
  }

  Widget _buildTransactionList(BuildContext context, List<Transaction> transactions) {
    final grouped = _groupTransactions(transactions);

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return CustomScrollView(
      slivers: [
        ...grouped.entries.map((entry) {
          // Per-day totals, like Google Pay — big numbers, no filler words:
          // "−₹74  +₹200", color-coded by direction.
          final spent = entry.value
              .where((t) => t.direction == 'debit')
              .fold(0.0, (sum, t) => sum + t.amount);
          final received = entry.value
              .where((t) => t.direction == 'credit')
              .fold(0.0, (sum, t) => sum + t.amount);

          return SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: RozzColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (spent > 0 || received > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (spent > 0)
                              Text(
                                '−${currency.format(spent)}',
                                style: GoogleFonts.dmMono(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: RozzColors.expense,
                                ),
                              ),
                            if (spent > 0 && received > 0) const SizedBox(width: 10),
                            if (received > 0)
                              Text(
                                '+${currency.format(received)}',
                                style: GoogleFonts.dmMono(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: RozzColors.income,
                                ),
                              ),
                          ],
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
                      final tx = entry.value[index];
                      return TransactionCard(
                        transaction: tx,
                        onTap: () => TransactionDetailsSheet.show(context, tx),
                      );
                    },
                    childCount: entry.value.length,
                  ),
                ),
              ),
            ],
          );
        }),
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
        header = 'TODAY, ${DateFormat('dd MMMM').format(date).toUpperCase()}';
      } else if (dateStr == yesterdayStr) {
        header = 'YESTERDAY, ${DateFormat('dd MMMM').format(date).toUpperCase()}';
      } else {
        header = DateFormat('dd MMMM yyyy').format(date).toUpperCase();
      }

      if (grouped[header] == null) {
        grouped[header] = [];
      }
      grouped[header]!.add(tx);
    }
    return grouped;
  }
}
