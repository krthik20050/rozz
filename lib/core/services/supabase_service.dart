import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rozz/core/security/secure_storage_service.dart';

/// Lazy-initializing singleton wrapper around the Supabase client.
///
/// Call [initializeFromStorage] once at app startup. After that every
/// component can use [client] to reach Supabase. If credentials have not
/// been saved yet [client] returns null and sync features degrade gracefully.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _initialized = false;

  bool get isInitialized => _initialized;

  SupabaseClient? get client {
    if (!_initialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Reads SUPABASE_URL and SUPABASE_ANON_KEY from secure storage and
  /// initialises the Supabase client. Returns true on success.
  Future<bool> initializeFromStorage(SecureStorageService storage) async {
    if (_initialized) return true;
    try {
      final url = await storage.readValue('SUPABASE_URL');
      final key = await storage.readValue('SUPABASE_ANON_KEY');
      if (url == null || url.isEmpty || key == null || key.isEmpty) {
        return false;
      }
      return await _doInit(url, key);
    } catch (e) {
      debugPrint('SupabaseService.initializeFromStorage: $e');
      return false;
    }
  }

  /// Initialise with explicit credentials (called from Settings after save).
  Future<bool> initialize(String url, String anonKey) async {
    if (_initialized) return true;
    return _doInit(url, anonKey);
  }

  Future<bool> _doInit(String url, String anonKey) async {
    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('SupabaseService._doInit: $e');
      return false;
    }
  }

  /// Generates a random RFC-4122 v4 UUID to use as a stable device identifier.
  static String generateDeviceId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
