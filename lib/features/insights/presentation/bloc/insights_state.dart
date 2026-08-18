part of 'insights_bloc.dart';

abstract class InsightsState extends Equatable {
  const InsightsState();

  @override
  List<Object?> get props => [];
}

class InsightsInitial extends InsightsState {}

class InsightsLoading extends InsightsState {}

class InsightsLoaded extends InsightsState {
  final MonthlySummary summary;
  final List<Subscription> subscriptions;

  /// Detected recurring charges with predicted next-charge dates.
  final List<UpcomingCharge> upcomingCharges;

  /// One entry per detected credit sender, resolved to a display name.
  final List<ResolvedSender> senders;

  /// User-defined sender labels, keyed by normalized sender key.
  final Map<String, String> senderLabels;

  /// Senders merged by display name, largest first (income tab).
  final List<IncomeSource> incomeSources;

  /// Credits that arrive most months from the same sender (salary, pension,
  /// allowance) — with whether this month's payment has landed.
  final List<RecurringIncome> recurringIncome;

  const InsightsLoaded({
    required this.summary,
    required this.subscriptions,
    required this.upcomingCharges,
    required this.senders,
    required this.senderLabels,
    required this.incomeSources,
    this.recurringIncome = const [],
  });

  @override
  List<Object?> get props => [
        summary,
        subscriptions,
        upcomingCharges,
        senders,
        senderLabels,
        incomeSources,
        recurringIncome,
      ];
}

class InsightsError extends InsightsState {
  final String message;

  const InsightsError(this.message);

  @override
  List<Object?> get props => [message];
}
