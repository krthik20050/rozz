import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/services/error_boundary.dart';

void main() {
  tearDown(() {
    ErrorBoundary.reset();
  });

  group('install / reset', () {
    test('install replaces ErrorWidget.builder and reset restores it', () {
      final before = ErrorWidget.builder;
      ErrorBoundary.install();
      expect(ErrorWidget.builder, isNot(same(before)));
      ErrorBoundary.reset();
      expect(ErrorWidget.builder, same(before));
    });

    test('platform error handler returns true so the app keeps running', () {
      ErrorBoundary.install();
      final handler = PlatformDispatcher.instance.onError;
      expect(handler, isNotNull);
      final handled = handler!(Exception('boom'), StackTrace.current);
      expect(handled, isTrue, reason: 'a stray async error must not kill the app');
    });

    test('logUncaught logs without throwing', () {
      // Should not throw even when the on-device log path is unavailable.
      ErrorBoundary.logUncaught(Exception('boom'), StackTrace.current);
    });
  });

  group('crash log file', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('rozz_crash_test_');
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test('appends timestamped entries', () async {
      final path = '${dir.path}/crash_log.txt';
      await ErrorBoundary.writeCrashLog(path, 'build', 'first error', StackTrace.current);
      await ErrorBoundary.writeCrashLog(path, 'platform', 'second error', null);

      final contents = await File(path).readAsString();
      expect(contents, contains('first error'));
      expect(contents, contains('second error'));
      expect(contents, contains('[build]'));
      expect(contents, contains('[platform]'));
      expect(contents.split('---').length, 3,
          reason: 'two entries separated by the --- marker');
    });

    test('resets the file when it grows past the cap', () async {
      final path = '${dir.path}/crash_log.txt';
      // First entry bigger than the whole cap.
      final big = 'x' * (ErrorBoundary.maxLogBytes + 8);
      await ErrorBoundary.writeCrashLog(path, 'build', big, null);

      // The file is now over the cap, so the NEXT write resets it instead of
      // appending — the giant entry is discarded.
      await ErrorBoundary.writeCrashLog(path, 'build', 'after reset', null);
      final contents = await File(path).readAsString();
      expect(contents, contains('after reset'));
      expect(contents, isNot(contains('x' * 1000)),
          reason: 'the giant entry was discarded on reset');
      expect(contents.length, lessThan(1000),
          reason: 'reset dropped the oversized entry');
    });
  });

  group('error fallback widget', () {
    testWidgets('renders the calm fallback instead of the red screen',
        (tester) async {
      ErrorBoundary.install();
      final fallback = ErrorWidget.builder(
        FlutterErrorDetails(exception: Exception('boom'), library: 'test'),
      );
      await tester.pumpWidget(MaterialApp(home: fallback));

      expect(find.textContaining('something went wrong'), findsOneWidget);
      expect(find.textContaining('your data is safe'), findsOneWidget);
      // Debug builds surface the exception for developers.
      expect(find.textContaining('boom'), findsOneWidget);

      // The test binding verifies ErrorWidget.builder is back to default by
      // the end of the test body — restore it here, not just in tearDown.
      ErrorBoundary.reset();
    });
  });
}
