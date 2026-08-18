import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/insights/presentation/bloc/insights_bloc.dart';
import 'package:rozz/features/insights/presentation/widgets/for_you_tab.dart';
import 'package:rozz/features/insights/presentation/widgets/income_tab.dart';
import 'package:rozz/features/insights/presentation/widgets/insights_skeletons.dart';
import 'package:rozz/features/insights/presentation/widgets/spending_tab.dart';
import 'package:rozz/features/insights/presentation/widgets/subscriptions_tab.dart';
import 'package:rozz/features/mab/presentation/bloc/mab_bloc.dart';
import 'package:rozz/shared/widgets/sliding_pill_bar.dart';
import 'package:rozz/shared/widgets/state_message.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  static const _tabs = ['for you', 'spending', 'subscriptions', 'income'];

  String _selectedTab = 'for you';

  /// Keeps the last loaded data on screen while a refresh is in flight, so
  /// the page never flashes back to skeletons after the first load.
  InsightsLoaded? _lastLoaded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: RozzColors.gold,
          backgroundColor: RozzColors.s2,
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: Text(
                    'insights',
                    style: GoogleFonts.syne(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: RozzColors.textPrimary,
                    ),
                  ),
                ),

                // Segmented Tabs — the gold pill slides to the selected label.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: SlidingPillBar(
                    labels: _tabs,
                    selected: _selectedTab,
                    onChanged: (label) => setState(() => _selectedTab = label),
                  ),
                ),

                const SizedBox(height: 16),

                // Tab content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildTabContent(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    final now = DateTime.now();
    context.read<InsightsBloc>().add(LoadInsights(now: now));
    context.read<MabBloc>().add(LoadMabStatus(month: now.month, year: now.year, now: now));
    // Wait a beat so the loading state can render behind the spinner, then
    // reassure: a tiny "updated" toast (micro-interaction research).
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: RozzColors.s2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 16, color: RozzColors.income),
              const SizedBox(width: 8),
              Text(
                'insights updated just now',
                style: GoogleFonts.dmSans(fontSize: 13, color: RozzColors.textPrimary),
              ),
            ],
          ),
        ),
      );
  }  Widget _buildTabContent(BuildContext context) {
    return BlocBuilder<InsightsBloc, InsightsState>(
      builder: (context, state) {
        if (state is InsightsLoaded) {
          _lastLoaded = state;
        }
        if (state is InsightsLoading || state is InsightsInitial) {
          // Progressive: keep showing stale data on refresh; only skeleton on
          // the very first load.
          if (_lastLoaded != null) return _buildTabFor(_lastLoaded!);
          return InsightsLoadingSkeleton(tab: _selectedTab);
        } else if (state is InsightsError) {
          if (_lastLoaded != null) return _buildTabFor(_lastLoaded!);
          return StateMessage.error(
            title: 'couldn\'t load your insights',
            message: 'Something went wrong while analyzing your transactions. Try again.',
            onRetry: () {
              final now = DateTime.now();
              context.read<InsightsBloc>().add(LoadInsights(now: now));
              context.read<MabBloc>().add(LoadMabStatus(month: now.month, year: now.year, now: now));
            },
          );
        } else if (state is InsightsLoaded) {
          return _buildTabFor(state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTabFor(InsightsLoaded state) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey('$_selectedTab-${state.senderLabels.length}'),
        child: switch (_selectedTab) {
          'for you' => ForYouTab(
              summary: state.summary,
              subscriptions: state.subscriptions,
            ),
          'spending' => SpendingTab(summary: state.summary),
          'subscriptions' => SubscriptionsTab(
              subscriptions: state.subscriptions,
              onDismiss: (key) => context
                  .read<InsightsBloc>()
                  .add(DismissSubscription(merchantKey: key)),
            ),
          'income' => IncomeTab(
              summary: state.summary,
              incomeSources: state.incomeSources,
              senders: state.senders,
              recurringIncome: state.recurringIncome,
            ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

}
