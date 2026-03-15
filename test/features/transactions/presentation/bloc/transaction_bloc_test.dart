import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:rozz/features/transactions/presentation/bloc/transaction_bloc.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class FakeTransaction extends Fake implements Transaction {}

void main() {
  late MockTransactionRepository mockRepository;
  late TransactionBloc transactionBloc;

  setUpAll(() {
    registerFallbackValue(FakeTransaction());
  });

  setUp(() {
    mockRepository = MockTransactionRepository();
    transactionBloc = TransactionBloc(mockRepository);
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

  group('LoadTransactions', () {
    blocTest<TransactionBloc, TransactionState>(
      'emits [TransactionLoading, TransactionLoaded] when LoadTransactions is added',
      build: () {
        when(() => mockRepository.getAllTransactions())
            .thenAnswer((_) async => tTransactions);
        when(() => mockRepository.getLastKnownBalance())
            .thenAnswer((_) async => 5000.0);
        return transactionBloc;
      },
      act: (bloc) => bloc.add(LoadTransactions()),
      expect: () => [
        TransactionLoading(),
        TransactionLoaded(tTransactions, 5000.0),
      ],
      verify: (_) {
        verify(() => mockRepository.getAllTransactions()).called(1);
        verify(() => mockRepository.getLastKnownBalance()).called(1);
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
        when(() => mockRepository.getLastKnownBalance())
            .thenAnswer((_) async => 5000.0);
        return transactionBloc;
      },
      act: (bloc) => bloc.add(const AddTransaction(tTransaction)),
      expect: () => [
        TransactionLoading(),
        TransactionLoaded(tTransactions, 5000.0),
      ],
      verify: (_) {
        verify(() => mockRepository.saveTransaction(any())).called(1);
      },
    );
  });
}
