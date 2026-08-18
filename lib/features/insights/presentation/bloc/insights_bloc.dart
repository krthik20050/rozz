import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rozz/features/insights/domain/entities/income_source.dart';
import 'package:rozz/features/insights/domain/entities/monthly_summary.dart';
import 'package:rozz/features/insights/domain/entities/recurring_income.dart';
import 'package:rozz/features/insights/domain/entities/resolved_sender.dart';
import 'package:rozz/features/insights/domain/entities/sender_label.dart';
import 'package:rozz/features/insights/domain/entities/subscription.dart';
import 'package:rozz/features/insights/domain/entities/upcoming_charge.dart';
import 'package:rozz/features/insights/domain/repositories/dismissed_subscription_repository.dart';
import 'package:rozz/features/insights/domain/repositories/sender_label_repository.dart';
import 'package:rozz/features/insights/domain/usecases/compute_monthly_summary.dart';
import 'package:rozz/features/insights/domain/usecases/compute_recurring_income.dart';
import 'package:rozz/features/insights/domain/usecases/compute_subscriptions.dart';
import 'package:rozz/features/insights/domain/usecases/compute_upcoming_charges.dart';
import 'package:rozz/features/insights/domain/usecases/resolve_sender_identities.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:rozz/shared/services/contact_resolver.dart';

part 'insights_event.dart';
part 'insights_state.dart';

class InsightsBloc extends Bloc<InsightsEvent, InsightsState> {
  final TransactionRepository _transactionRepository;
  final SenderLabelRepository _senderLabelRepository;
  final DismissedSubscriptionRepository _dismissedSubscriptionRepository;
  final ContactResolver _contactResolver;
  final ComputeMonthlySummary _computeMonthlySummary;
  final ComputeSubscriptions _computeSubscriptions;
  final ComputeUpcomingCharges _computeUpcomingCharges;
  final ResolveSenderIdentities _resolveSenderIdentities;
  final ComputeRecurringIncome _computeRecurringIncome;

  InsightsBloc(
    this._transactionRepository,
    this._senderLabelRepository,
    this._dismissedSubscriptionRepository,
    this._contactResolver,
    this._computeMonthlySummary,
    this._computeSubscriptions,
    this._computeUpcomingCharges,
    this._resolveSenderIdentities,
    this._computeRecurringIncome,
  ) : super(InsightsInitial()) {
    on<LoadInsights>(_onLoadInsights);
    on<SaveSenderLabel>(_onSaveSenderLabel);
    on<DeleteSenderLabel>(_onDeleteSenderLabel);
    on<CheckContacts>(_onCheckContacts);
    on<DismissSubscription>(_onDismissSubscription);
    on<RestoreSubscription>(_onRestoreSubscription);
  }

  Future<void> _onLoadInsights(
    LoadInsights event,
    Emitter<InsightsState> emit,
  ) async {
    emit(InsightsLoading());
    try {
      final now = event.now ?? DateTime.now();
      final prior = DateTime(now.year, now.month - 1, 1);

      final monthTransactions = await _transactionRepository
          .getTransactionsByMonth(now.month, now.year);
      final priorTransactions = await _transactionRepository
          .getTransactionsByMonth(prior.month, prior.year);
      // Subscription detection needs history, not just the current month.
      final allTransactions = await _transactionRepository.getAllTransactions();

      final labels = await _loadLabels();
      final contactPhoneToName = await _contactResolver.phoneToName();
      final dismissed = await _dismissedSubscriptionRepository.getAll();

      final summary = _computeMonthlySummary(
        monthTransactions: monthTransactions,
        priorMonthTransactions: priorTransactions,
        month: now.month,
        year: now.year,
      );
      final subscriptions =
          _computeSubscriptions(transactions: allTransactions, dismissedKeys: dismissed);
      final upcomingCharges = _computeUpcomingCharges(
        subscriptions: subscriptions,
        today: now,
      );
      var resolved = _resolveSenderIdentities(
        transactions: monthTransactions,
        labels: labels,
        contactPhoneToName: contactPhoneToName,
      );

      // Contact matches become real labels, automatically: a sender matched
      // from the address book should show that name everywhere (cards,
      // activity, income) without the user visiting manage-senders. Persist
      // once, then re-resolve so the label wins on the next render.
      final autoApplied = <String, String>{};
      for (final sender in resolved.senders) {
        if (sender.identification == 'contact' &&
            labels[sender.key] == null &&
            labels[sender.key.split('@').first] == null) {
          autoApplied[sender.key] = sender.displayName;
        }
      }
      if (autoApplied.isNotEmpty) {
        for (final entry in autoApplied.entries) {
          await _senderLabelRepository.upsert(
            SenderLabel(key: entry.key, label: entry.value),
          );
        }
        labels.addAll(autoApplied);
        resolved = _resolveSenderIdentities(
          transactions: monthTransactions,
          labels: labels,
          contactPhoneToName: contactPhoneToName,
        );
      }

      final recurringIncome = _computeRecurringIncome(
        transactions: allTransactions,
        labels: labels,
        contactPhoneToName: contactPhoneToName,
        now: now,
      );

      emit(InsightsLoaded(
        summary: summary,
        subscriptions: subscriptions,
        upcomingCharges: upcomingCharges,
        senders: resolved.senders,
        senderLabels: labels,
        incomeSources: resolved.incomeSources,
        recurringIncome: recurringIncome,
      ));
    } catch (e) {
      emit(InsightsError(e.toString()));
    }
  }

  Future<void> _onSaveSenderLabel(
    SaveSenderLabel event,
    Emitter<InsightsState> emit,
  ) async {
    try {
      await _senderLabelRepository.upsert(
        SenderLabel(key: event.key, label: event.label),
      );
      add(LoadInsights(now: event.now));
    } catch (e) {
      emit(InsightsError(e.toString()));
    }
  }

  Future<void> _onDeleteSenderLabel(
    DeleteSenderLabel event,
    Emitter<InsightsState> emit,
  ) async {
    try {
      await _senderLabelRepository.delete(event.key);
      add(LoadInsights(now: event.now));
    } catch (e) {
      emit(InsightsError(e.toString()));
    }
  }

  Future<void> _onCheckContacts(
    CheckContacts event,
    Emitter<InsightsState> emit,
  ) async {
    try {
      // Drop the cached lookup so the next load re-reads the address book
      // (permission may have just been granted in system settings).
      await _contactResolver.refreshPhoneToName();
      add(LoadInsights(now: event.now));
    } catch (e) {
      emit(InsightsError(e.toString()));
    }
  }

  Future<void> _onDismissSubscription(
    DismissSubscription event,
    Emitter<InsightsState> emit,
  ) async {
    try {
      await _dismissedSubscriptionRepository.dismiss(event.merchantKey);
      add(LoadInsights(now: event.now));
    } catch (e) {
      emit(InsightsError(e.toString()));
    }
  }

  Future<void> _onRestoreSubscription(
    RestoreSubscription event,
    Emitter<InsightsState> emit,
  ) async {
    try {
      await _dismissedSubscriptionRepository.restore(event.merchantKey);
      add(LoadInsights(now: event.now));
    } catch (e) {
      emit(InsightsError(e.toString()));
    }
  }

  Future<Map<String, String>> _loadLabels() async {
    final labels = await _senderLabelRepository.getAll();
    return {for (final l in labels) l.key: l.label};
  }
}
