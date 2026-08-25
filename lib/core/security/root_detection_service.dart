import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Checks whether the device is rooted (Android) or jailbroken (iOS).
///
/// Detection is best-effort — no check is 100% reliable on a compromised
/// device. The service is deliberately non-blocking: it returns a result
/// the UI can show as a warning banner, never a hard gate.
class RootDetectionService {
  static const _channel = MethodChannel('com.rozz/security');

  /// Returns `true` if the device appears rooted/jailbroken.
  /// Always returns `false` on web or desktop (where jailbreak is N/A).
  Future<bool> isDeviceCompromised() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isDeviceRooted');
      return result ?? false;
    } catch (e) {
      debugPrint('Root detection failed (assume safe): $e');
      return false;
    }
  }
}
