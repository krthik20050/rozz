import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage}) 
    : _storage = storage ?? const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );

  /// Write sensitive value to Android Keystore
  Future<void> writeValue(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      throw Exception('Security: Failed to write to keystore: ' + e.toString());
    }
  }

  /// Read sensitive value from Android Keystore
  Future<String?> readValue(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      throw Exception('Security: Failed to read from keystore: ' + e.toString());
    }
  }

  /// Delete sensitive value
  Future<void> deleteValue(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      throw Exception('Security: Failed to delete from keystore: ' + e.toString());
    }
  }

  /// Clear all secure storage - use with caution
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw Exception('Security: Failed to clear keystore: ' + e.toString());
    }
  }
}
