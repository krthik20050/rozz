import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/security/secure_storage_service.dart';

/// Explicit, debug-only desktop sandbox. Never touches a mobile ledger.
bool get desktopPreviewEnabled =>
    !kReleaseMode &&
    !kIsWeb &&
    Platform.isWindows &&
    const bool.fromEnvironment('ROZZ_DESKTOP_PREVIEW');

/// Synthetic, current-month inputs for the real SMS parser and ingest path.
List<Map<String, Object>> previewMessages(DateTime now) {
  final messages = <Map<String, Object>>[];
  final format = DateFormat('dd-MMM-yy');
  for (var day = 1; day <= now.day; day++) {
    final date = DateTime(now.year, now.month, day, 9);
    final balance = 18000 - day * 120;
    messages.add({
      'body':
          'Available Bal in A/c XX4321 as on ${format.format(date)} '
          'is INR $balance. HDFC Bank',
      'date': date.millisecondsSinceEpoch,
    });
  }
  messages.add({
    'body':
        'Rs.120 debited from HDFC Bank A/c XX4321 to Aarav. '
        'Avl bal: Rs.${18000 - now.day * 120}. Ref PREVIEWDEBIT01',
    'date': now.millisecondsSinceEpoch,
  });
  return messages;
}

/// Preview credentials/settings exist only for the lifetime of this process.
class PreviewSecureStorage extends SecureStorageService {
  final Map<String, String> _values = {'onboarding_complete': 'true'};

  @override
  Future<void> writeValue(String key, String value) =>
      Future.sync(() => _values[key] = value);

  @override
  Future<String?> readValue(String key) => Future.value(_values[key]);

  @override
  Future<void> deleteValue(String key) => Future.sync(() {
    _values.remove(key);
  });

  @override
  Future<void> deleteAll() => Future.sync(_values.clear);
}
