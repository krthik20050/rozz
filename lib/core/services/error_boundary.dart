import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:sqflite/sqflite.dart';

/// Installs the app's global error handling so an unexpected crash never shows
/// the raw red (debug) / grey (release) error screen:
///
///  • [FlutterError.onError] — framework errors (build/layout/paint). Keeps the
///    default console dump via [FlutterError.presentError] AND writes the crash
///    to a persistent log file.
///  • [PlatformDispatcher.instance.onError] — uncaught async errors from the
///    engine. Returned `true` so a stray async error doesn't kill the app.
///  • [ErrorWidget.builder] — replaces the red/grey error widget with a calm,
///    on-brand fallback ("something went wrong — your data is safe on this
///    phone").
///
/// Every crash is also logged to `crash_log.txt` next to the database, so a
/// real device failure can be pulled off the phone even though the encrypted DB
/// itself isn't host-readable. The log is capped so it can't grow forever.
///
/// Call once from `main()` (wrapped in [runZonedGuarded] for extra coverage of
/// async errors that escape the zone).
class ErrorBoundary {
  static const String logFileName = 'crash_log.txt';

  /// Hard cap so the on-device debug log can't grow unbounded.
  static const int maxLogBytes = 200 * 1024;

  /// Saves the handlers this class replaced, so tests can restore them.
  static void Function(FlutterErrorDetails)? _previousFlutterHandler;
  static bool Function(Object, StackTrace)? _previousPlatformHandler;
  static Widget Function(FlutterErrorDetails)? _previousErrorWidgetBuilder;

  /// Installs the boundary. Idempotent.
  static void install() {
    _previousFlutterHandler ??= FlutterError.onError;
    _previousPlatformHandler ??= PlatformDispatcher.instance.onError;
    _previousErrorWidgetBuilder ??= ErrorWidget.builder;

    FlutterError.onError = (details) {
      // Keep the framework's own console dump (it prints the widget tree).
      FlutterError.presentError(details);
      unawaited(_logCrash('build', details.exceptionAsString(), details.stack));
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(_logCrash('platform', error.toString(), stack));
      // Return true = handled: a stray async error must not kill the app.
      return true;
    };

    ErrorWidget.builder = (details) => _RozzErrorFallback(details: details);
  }

  /// Entry point for [runZonedGuarded]'s handler: logs async errors that escape
  /// every other handler without killing the app.
  static void logUncaught(Object error, StackTrace stack) {
    debugPrint('ROZZ uncaught async error: $error\n$stack');
    unawaited(_logCrash('uncaught', error.toString(), stack));
  }

  /// Restores whatever handlers were in place before [install] (test cleanup).
  static void reset() {
    if (_previousFlutterHandler != null) FlutterError.onError = _previousFlutterHandler;
    if (_previousPlatformHandler != null) {
      PlatformDispatcher.instance.onError = _previousPlatformHandler;
    }
    if (_previousErrorWidgetBuilder != null) {
      ErrorWidget.builder = _previousErrorWidgetBuilder!;
    }
    _previousFlutterHandler = null;
    _previousPlatformHandler = null;
    _previousErrorWidgetBuilder = null;
  }

  /// Appends a crash entry to the on-device log (best-effort — never throws,
  /// because logging must not make the original crash worse).
  static Future<void> _logCrash(String kind, String error, StackTrace? stack) async {
    debugPrint('ROZZ crash [$kind]: $error');
    if (stack != null) debugPrint(stack.toString());
    try {
      final dir = await getDatabasesPath();
      await writeCrashLog('$dir/$logFileName', kind, error, stack);
    } catch (_) {
      // Platform logging unavailable (e.g. tests) — console log still happened.
    }
  }

  /// Appends one timestamped entry to [path], resetting the file when it grows
  /// past [maxLogBytes]. Separated out so it's unit-testable without plugins.
  @visibleForTesting
  static Future<void> writeCrashLog(
    String path,
    String kind,
    String error,
    StackTrace? stack,
  ) async {
    final file = File(path);
    final entry = '${DateTime.now().toIso8601String()} [$kind] $error\n'
        '${stack?.toString() ?? '(no stack)'}\n---\n';
    if (await file.exists() && await file.length() > maxLogBytes) {
      await file.writeAsString(entry);
    } else {
      await file.writeAsString(entry, mode: FileMode.append);
    }
  }
}

/// The calm, on-brand widget shown in place of the default red/grey error
/// screen. In debug builds the exception is shown (small, muted) so a developer
/// can read it at a glance; release builds never leak error internals.
class _RozzErrorFallback extends StatelessWidget {
  final FlutterErrorDetails details;

  const _RozzErrorFallback({required this.details});

  @override
  Widget build(BuildContext context) {
    final message = details.exceptionAsString();
    return Scaffold(
      backgroundColor: RozzColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: RozzColors.gold, size: 40),
              const SizedBox(height: 16),
              const Text(
                'something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RozzColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'your data is safe on this phone. restart ROZZ to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RozzColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (kDebugMode && message.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: RozzColors.s1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    message.length > 240 ? '${message.substring(0, 240)}…' : message,
                    style: const TextStyle(
                      color: RozzColors.textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
