import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rozz/core/security/secure_storage_service.dart';
import 'package:rozz/core/services/ai_service.dart';
import 'package:rozz/features/chat/presentation/pages/chat_rozz_page.dart';
import 'package:rozz/features/insights/domain/entities/sender_label.dart';
import 'package:rozz/features/insights/domain/repositories/dismissed_subscription_repository.dart';
import 'package:rozz/features/insights/domain/repositories/sender_label_repository.dart';
import 'package:rozz/features/insights/domain/usecases/compute_monthly_summary.dart';
import 'package:rozz/features/insights/domain/usecases/compute_recurring_income.dart';
import 'package:rozz/features/insights/domain/usecases/compute_subscriptions.dart';
import 'package:rozz/features/insights/domain/usecases/compute_upcoming_charges.dart';
import 'package:rozz/features/insights/domain/usecases/resolve_sender_identities.dart';
import 'package:rozz/features/insights/presentation/bloc/insights_bloc.dart';
import 'package:rozz/features/mab/domain/entities/mab_record.dart';
import 'package:rozz/features/mab/domain/repositories/mab_repository.dart';
import 'package:rozz/features/mab/domain/usecases/calculate_mab.dart';
import 'package:rozz/features/mab/presentation/bloc/mab_bloc.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:rozz/shared/services/contact_resolver.dart';

/// In-memory secure storage so the chat's key check sees a configured key.
class FakeSecureStorage extends SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<String?> readValue(String key) async => _store[key];

  @override
  Future<void> writeValue(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> deleteValue(String key) async {
    _store.remove(key);
  }
}

/// AI service that never touches the network — the test drives its stream.
class FakeAiService extends AiService {
  FakeAiService(super.storage);

  final StreamController<String> controller = StreamController<String>();
  String? lastQuery;
  String? lastContext;

  @override
  Stream<String> streamFinancialAssistant(
    String query, {
    String? context,
    List<Map<String, String>> history = const [],
  }) {
    lastQuery = query;
    lastContext = context;
    return controller.stream;
  }
}

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockMabRepository extends Mock implements MabRepository {}

class MockSenderLabelRepository extends Mock implements SenderLabelRepository {}

class MockDismissedSubscriptionRepository extends Mock
    implements DismissedSubscriptionRepository {}

void main() {
  late FakeSecureStorage storage;
  late FakeAiService ai;
  late MockTransactionRepository txnRepo;
  late MockMabRepository mabRepo;

  setUpAll(() {
    registerFallbackValue(const SenderLabel(key: 'fallback', label: 'fallback'));
    registerFallbackValue(const MabRecord(
      date: '2026-01-01',
      endOfDayBalance: 0,
      month: 1,
      year: 2026,
    ));
  });

  setUp(() {
    storage = FakeSecureStorage();
    ai = FakeAiService(storage);
    txnRepo = MockTransactionRepository();
    mabRepo = MockMabRepository();

    when(() => txnRepo.getAllTransactions()).thenAnswer((_) async => []);
    when(() => txnRepo.getTransactionsByMonth(any(), any()))
        .thenAnswer((_) async => []);
    when(() => txnRepo.getLastKnownBalance()).thenAnswer((_) async => null);
    when(() => mabRepo.getMonthRecords(any(), any())).thenAnswer((_) async => []);
    when(() => mabRepo.insertEodBalance(any())).thenAnswer((_) async {});
    when(() => mabRepo.getMissingDays(any(), any())).thenAnswer((_) async => []);

    // A configured key so the chat skips the setup screen.
    storage.writeValue(AiService.apiKeyStorageKey, 'gsk_test');
  });

  Future<void> pumpChat(WidgetTester tester) async {
    final insights = InsightsBloc(
      txnRepo,
      MockSenderLabelRepository(),
      MockDismissedSubscriptionRepository(),
      ContactResolver(fetch: () async => const []),
      ComputeMonthlySummary(),
      ComputeSubscriptions(),
      ComputeUpcomingCharges(),
      ResolveSenderIdentities(),
      ComputeRecurringIncome(),
    );
    final mab = MabBloc(
      mabRepo,
      CalculateMab(),
      txnRepo,
      storage,
    );
    addTearDown(insights.close);
    addTearDown(mab.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<InsightsBloc>.value(value: insights),
            BlocProvider<MabBloc>.value(value: mab),
          ],
          child: ChatRozzPage(
            aiService: ai,
            secureStorage: storage,
            transactionRepository: txnRepo,
          ),
        ),
      ),
    );
    // Let initState's async key check settle.
    await tester.pump();
    await tester.pump();
  }

  Future<void> sendMessage(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('typing and sending a message does not throw and shows the reply',
      (tester) async {
    await pumpChat(tester);

    await sendMessage(tester, 'how much did I spend?');

    expect(tester.takeException(), isNull,
        reason: 'no exception while sending a chat message');

    // Drive the fake stream and finish it.
    ai.controller.add('You spent ');
    ai.controller.add('₹5,000 this month.');
    await tester.pump();
    await ai.controller.close();
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'no exception while rendering the assistant reply');
    expect(find.textContaining('You spent'), findsOneWidget);
  });

  testWidgets('an assistant reply with a markdown table renders without throwing',
      (tester) async {
    await pumpChat(tester);

    await sendMessage(tester, 'list my subscriptions');

    ai.controller.add('| Service | Cost |\n|---|---|\n| Netflix | ₹649 |\n| Spotify | ₹119 |');
    await tester.pump();
    await ai.controller.close();
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'table markdown must not crash the chat');
    expect(find.textContaining('Netflix'), findsOneWidget);
  });

  testWidgets('stream error surfaces a fallback message, not a crash',
      (tester) async {
    await pumpChat(tester);

    await sendMessage(tester, 'hello');

    ai.controller.addError(Exception('boom'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'stream errors must be caught, not crash the tree');
    expect(find.textContaining('Something went wrong'), findsOneWidget);
  });

  testWidgets('no key shows the setup screen and typing still works',
      (tester) async {
    storage.deleteValue(AiService.apiKeyStorageKey);
    await pumpChat(tester);

    expect(find.textContaining('connect ROZZ'), findsOneWidget);

    // Composer is always available; sending without a key yields the
    // no-key message through the real service path.
    await tester.enterText(find.byType(TextField).first, 'hi');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump();

    // FakeAiService overrides the stream, so the no-key message comes from
    // our fake. Just assert nothing crashed.
    expect(tester.takeException(), isNull);
  });
}
