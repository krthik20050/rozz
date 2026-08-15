import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? _defaultStorage;

  static const _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  final FlutterSecureStorage _storage;

  Future<void> writeValue(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> readValue(String key) => _storage.read(key: key);

  Future<void> deleteValue(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();
}