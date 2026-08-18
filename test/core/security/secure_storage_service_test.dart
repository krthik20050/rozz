import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/security/secure_storage_service.dart';

void main() {
  late SecureStorageService service;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    service = SecureStorageService();
  });

  test('writeValue then readValue round-trips', () async {
    await service.writeValue('AI_API_KEY', 'test-key');
    expect(await service.readValue('AI_API_KEY'), 'test-key');
  });

  test('readValue returns null for missing key', () async {
    expect(await service.readValue('missing'), isNull);
  });

  test('deleteValue removes the key', () async {
    await service.writeValue('k', 'v');
    await service.deleteValue('k');
    expect(await service.readValue('k'), isNull);
  });

  test('deleteAll clears everything', () async {
    await service.writeValue('k1', 'v1');
    await service.writeValue('k2', 'v2');
    await service.deleteAll();
    expect(await service.readValue('k1'), isNull);
    expect(await service.readValue('k2'), isNull);
  });
}