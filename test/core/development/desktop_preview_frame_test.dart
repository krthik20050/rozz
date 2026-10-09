import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/database/database_helper.dart';
import 'package:rozz/core/development/desktop_preview_frame.dart';
import 'package:rozz/core/services/transaction_sync_service.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';
import 'package:rozz/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:rozz/features/transactions/data/repositories/transaction_repository_impl.dart';

void main() {
  testWidgets(
    'preview dialog uses the app navigator and imports through real ingest',
    (tester) async {
      final database = DatabaseHelper();
      final repo = TransactionRepositoryImpl(
        TransactionLocalDatasourceImpl(database),
      );
      final sync = TransactionSyncService(repo, database, SmsParser());
      final navigator = GlobalKey<NavigatorState>();
      var refreshes = 0;
      try {
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            builder: (context, child) => DesktopPreviewFrame(
              navigatorKey: navigator,
              syncService: sync,
              onImported: () => refreshes++,
              child: child!,
            ),
            home: const Scaffold(body: Text('Existing app screens')),
          ),
        );
        await tester.tap(find.text('Simulate SMS'));
        await tester.pumpAndSettle();
        expect(find.text('Simulate a bank SMS'), findsOneWidget);
        await tester.tap(find.text('Import'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          try {
            // Wait for the real FFI write rather than a mocked repository.
            for (var attempt = 0; refreshes == 0 && attempt < 50; attempt++) {
              await Future<void>.delayed(const Duration(milliseconds: 20));
            }
          } catch (_) {
            rethrow;
          } finally {
            /* bounded wait */
          }
        });
        await tester.pump(const Duration(seconds: 1));
        expect(refreshes, 1);
        expect(
          (await tester.runAsync(repo.getAllTransactions))!.single.amount,
          250,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        await tester.runAsync(database.close);
      }
    },
  );
}
