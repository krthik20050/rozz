import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:rozz/features/transactions/domain/usecases/compute_current_balance.dart';
import 'package:rozz/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:rozz/core/services/ai_service.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockAiService extends Mock implements AiService {}

class FakeTransaction extends Fake implements Transaction {}

void main() {
  late MockTransactionRepository mockRepository;
  late MockAiService mockAiService;
  late TransactionBloc transactionBloc;

  setUpAll(() {
    registerFallbackValue(FakeTransaction());
  });

  setUp(() {
    mockRepository = MockTransactionRepository();
    mockAiService = MockAiService();
    transactionBloc = TransactionBloc(mockRepository, mockAiService);
  });

  tearDown(() {
    transactionBloc.close();
  });

  const tTransaction = Transaction(
    id: 1,
    date: '2026-03-04T10:00:00Z',
    amount: 100.0,
    direction: 'debit',
    labelType: 'upi_debit',
    source: 'sms',
  );

  final tTransactions = [tTransaction];

  const tComputedBalance = ComputedBalance(
    value: 5000.0,
    replayedTransactions: 3,
    anchoredOn: '2026-03-04',
    confidence: BalanceConfidence.bankVerified,
  );

  group('LoadTransactions', () {
    blocTest<TransactionBloc, TransactionState>(
      'emits [TransactionLoading, TransactionLoaded] when LoadTransactions is added',
      build: () {
        when(() => mockRepository.getAllTransactions())
            .thenAnswer((_) async => tTransactions);
        when(() => mockRepository.computeBalance())
            .thenAnswer((_) async => tComputedBalance);
        return transactionBloc;
      },
      act: (bloc) => bloc.add(LoadTransactions()),
      expect: () => [
        TransactionLoading(),
        TransactionLoaded(tTransactions, 5000.0, bankVerified: true),
      ],
      verify: (_) {
        verify(() => mockRepository.getAllTransactions()).called(1);
        verify(() => mockRepository.computeBalance()).called(1);
      },
    );

    blocTest<TransactionBloc, TransactionState>(
      'emits [TransactionLoading, TransactionError] when loading fails',
      build: () {
        when(() => mockRepository.getAllTransactions())
            .thenThrow(Exception('Failed to load'));
        return transactionBloc;
      },
      act: (bloc) => bloc.add(LoadTransactions()),
      expect: () => [
        TransactionLoading(),
        const TransactionError('Exception: Failed to load'),
      ],
    );
  });

  group('AddTransaction', () {
    blocTest<TransactionBloc, TransactionState>(
      'calls saveTransaction and reloads transactions',
      build: () {
        when(() => mockRepository.saveTransaction(any()))
            .thenAnswer((_) async => {});
        when(() => mockRepository.getAllTransactions())
            .thenAnswer((_) async => tTransactions);
        when(() => mockRepository.computeBalance())
            .thenAnswer((_) async => tComputedBalance);
        return transactionBloc;
      },
      act: (bloc) => bloc.add(const AddTransaction(tTransaction)),
      expect: () => [
        TransactionLoading(),
        TransactionLoaded(tTransactions, 5000.0, bankVerified: true),
      ],
      verify: (_) {
        verify(() => mockRepository.saveTransaction(any())).called(1);
      },
    );
  });
}
