import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rozz/features/insights/domain/usecases/compute_monthly_summary.dart';
import 'package:rozz/features/monthly_review/presentation/bloc/monthly_review_bloc.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockTransactionRepository mockRepository;
  late MonthlyReviewBloc bloc;

  setUp(() {
    mockRepository = MockTransactionRepository();
    bloc = MonthlyReviewBloc(mockRepository, ComputeMonthlySummary());
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
      amount: 1000,
      direction: 'credit',
      labelType: 'upi',
      recipientName: 'EMPLOYER INC',
      source: 'sms',
    ),
  ];

  final priorTxns = [
    TransactionModel(
      date: '2026-07-01',
      amount: 200,
      direction: 'debit',
      labelType: 'upi',
      recipientName: 'SWIGGY',
      source: 'sms',
    ),
  ];

  blocTest<MonthlyReviewBloc, MonthlyReviewState>(
    'loads current + prior month and emits the computed summary',
    build: () {
      when(() => mockRepository.getTransactionsByMonth(8, 2026))
          .thenAnswer((_) async => monthTxns);
      when(() => mockRepository.getTransactionsByMonth(7, 2026))
          .thenAnswer((_) async => priorTxns);
      return bloc;
    },
    act: (bloc) => bloc.add(const LoadMonthlyReview(month: 8, year: 2026)),
    expect: () => [
      isA<MonthlyReviewLoading>(),
      isA<MonthlyReviewLoaded>().having(
        (s) => s.summary,
        'summary',
        isA<dynamic>().having((m) => m.received, 'received', 1000.0)
          ..having((m) => m.spent, 'spent', 500.0),
      ),
    ],
    verify: (_) {
      verify(() => mockRepository.getTransactionsByMonth(8, 2026)).called(1);
      verify(() => mockRepository.getTransactionsByMonth(7, 2026)).called(1);
    },
  );

  blocTest<MonthlyReviewBloc, MonthlyReviewState>(
    'emits error when the repository fails',
    build: () {
      when(() => mockRepository.getTransactionsByMonth(any(), any()))
          .thenThrow(Exception('db down'));
      return bloc;
    },
    act: (bloc) => bloc.add(const LoadMonthlyReview(month: 8, year: 2026)),
    expect: () => [
      isA<MonthlyReviewLoading>(),
      isA<MonthlyReviewError>().having(
        (s) => s.message,
        'message',
        contains('db down'),
      ),
    ],
  );
}
