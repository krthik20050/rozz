import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rozz/features/insights/domain/entities/sender_label.dart';
import 'package:rozz/features/insights/domain/repositories/dismissed_subscription_repository.dart';
import 'package:rozz/features/insights/domain/repositories/sender_label_repository.dart';
import 'package:rozz/features/insights/domain/usecases/compute_monthly_summary.dart';
import 'package:rozz/features/insights/domain/usecases/compute_recurring_income.dart';
import 'package:rozz/features/insights/domain/usecases/compute_subscriptions.dart';
import 'package:rozz/features/insights/domain/usecases/compute_upcoming_charges.dart';
import 'package:rozz/features/insights/domain/usecases/resolve_sender_identities.dart';
import 'package:rozz/features/insights/presentation/bloc/insights_bloc.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:rozz/shared/services/contact_resolver.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockSenderLabelRepository extends Mock implements SenderLabelRepository {}

class MockDismissedSubscriptionRepository extends Mock
    implements DismissedSubscriptionRepository {}

void main() {
  late MockTransactionRepository mockRepository;
  late MockSenderLabelRepository mockLabelRepository;
  late MockDismissedSubscriptionRepository mockDismissedRepository;
  late InsightsBloc bloc;

  setUpAll(() {
    registerFallbackValue(const SenderLabel(key: 'fallback', label: 'fallback'));
  });

  setUp(() {
    mockRepository = MockTransactionRepository();
    mockLabelRepository = MockSenderLabelRepository();
    mockDismissedRepository = MockDismissedSubscriptionRepository();
    when(() => mockDismissedRepository.getAll()).thenAnswer((_) async => const {});
    bloc = InsightsBloc(
      mockRepository,
      mockLabelRepository,
      mockDismissedRepository,
      ContactResolver(fetch: () async => const []),
      ComputeMonthlySummary(),
      ComputeSubscriptions(),
      ComputeUpcomingCharges(),
      ResolveSenderIdentities(),
      ComputeRecurringIncome(),
    );
  });

  tearDown(() {
    bloc.close();
  });

  final monthTxns = [
    TransactionModel(
      date: '2026-08-01',
      amount: 500,
      direction: 'debit',
      labelType: 'upi',
      recipientName: 'SWIGGY',
      source: 'sms',
    ),
    TransactionModel(
      date: '2026-08-02',
      amount: 2000,
      direction: 'credit',
      labelType: 'upi',
      recipientName: 'KK9396@OKHDFCBANK',
      source: 'sms',
    ),
  ];

  final priorTxns = [
    TransactionModel(
      date: '2026-07-01',
      amount: 300,
      direction: 'debit',
      labelType: 'upi',
      recipientName: 'SWIGGY',
      source: 'sms',
    ),
  ];

  final history = [
    ...priorTxns,
    ...monthTxns,
    TransactionModel(
      date: '2026-06-01',
      amount: 649,
      direction: 'debit',
      labelType: 'upi',
      recipientName: 'NETFLIX ENT',
      source: 'sms',
    ),
    TransactionModel(
      date: '2026-07-01',
      amount: 649,
      direction: 'debit',
      labelType: 'upi',
      recipientName: 'NETFLIX ENT',
      source: 'sms',
    ),
    TransactionModel(
      date: '2026-08-01',
      amount: 649,
      direction: 'debit',
      labelType: 'upi',
      recipientName: 'NETFLIX ENT',
      source: 'sms',
    ),
  ];

  blocTest<InsightsBloc, InsightsState>(
    'loads summary, subscriptions, upcoming charges and identified senders',
    build: () {
      when(() => mockRepository.getTransactionsByMonth(8, 2026))
          .thenAnswer((_) async => monthTxns);
      when(() => mockRepository.getTransactionsByMonth(7, 2026))
          .thenAnswer((_) async => priorTxns);
      when(() => mockRepository.getAllTransactions())
          .thenAnswer((_) async => history);
      when(() => mockLabelRepository.getAll()).thenAnswer((_) async => [
            const SenderLabel(key: 'kk9396', label: 'father'),
          ]);
      return bloc;
    },
    act: (bloc) => bloc.add(LoadInsights(now: DateTime(2026, 8, 15))),
    expect: () => [
      isA<InsightsLoading>(),
      isA<InsightsLoaded>()
          .having((s) => s.summary.received, 'received', 2000.0)
          .having((s) => s.summary.spent, 'spent', 500.0)
          .having((s) => s.summary.categories.first.category, 'top category', 'Food')
          .having((s) => s.subscriptions.single.merchant, 'subscription', 'Netflix')
          .having((s) => s.subscriptions.single.monthlyAmount, 'sub amount', 649.0)
          // Upcoming charges: Netflix charged on the 1st → next 1 Sep, but
          // today is 15 Aug — 17 days out, outside the 7-day reminder window,
          // so it correctly stays quiet (no nagging weeks early).
          .having((s) => s.upcomingCharges, 'upcoming (windowed)', isEmpty)
          // Label resolved the sender to "father".
          .having((s) => s.senders.single.displayName, 'sender name', 'father')
          .having((s) => s.incomeSources.single.recipient, 'income source', 'father')
          .having((s) => s.incomeSources.single.amount, 'income amount', 2000.0),
    ],
  );

  blocTest<InsightsBloc, InsightsState>(
    'save sender label persists and reloads',
    build: () {
      when(() => mockRepository.getTransactionsByMonth(any(), any()))
          .thenAnswer((_) async => monthTxns);
      when(() => mockRepository.getAllTransactions())
          .thenAnswer((_) async => history);
      when(() => mockLabelRepository.getAll()).thenAnswer((_) async => const []);
      when(() => mockLabelRepository.upsert(any())).thenAnswer((_) async {});
      return bloc;
    },
    act: (bloc) => bloc.add(SaveSenderLabel(key: 'kk9396', label: 'father')),
    expect: () => [
      isA<InsightsLoading>(),
      isA<InsightsLoaded>(),
    ],
    verify: (_) {
      verify(() => mockLabelRepository.upsert(
            any(that: isA<SenderLabel>()),
          )).called(1);
    },
  );

  blocTest<InsightsBloc, InsightsState>(
    'delete sender label persists and reloads',
    build: () {
      when(() => mockRepository.getTransactionsByMonth(any(), any()))
          .thenAnswer((_) async => monthTxns);
      when(() => mockRepository.getAllTransactions())
          .thenAnswer((_) async => history);
      when(() => mockLabelRepository.getAll()).thenAnswer((_) async => const []);
      when(() => mockLabelRepository.delete(any())).thenAnswer((_) async {});
      return bloc;
    },
    act: (bloc) => bloc.add(DeleteSenderLabel(key: 'kk9396')),
    expect: () => [
      isA<InsightsLoading>(),
      isA<InsightsLoaded>(),
    ],
    verify: (_) {
      verify(() => mockLabelRepository.delete('kk9396')).called(1);
    },
  );

  blocTest<InsightsBloc, InsightsState>(
    'emits error when the repository fails',
    build: () {
      when(() => mockRepository.getTransactionsByMonth(any(), any()))
          .thenThrow(Exception('db down'));
      return bloc;
    },
    act: (bloc) => bloc.add(LoadInsights(now: DateTime(2026, 8, 15))),
    expect: () => [
      isA<InsightsLoading>(),
      isA<InsightsError>().having((s) => s.message, 'message', contains('db down')),
    ],
  );
}
