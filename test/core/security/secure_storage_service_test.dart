import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rozz/core/security/secure_storage_service.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late SecureStorageService service;
  late MockFlutterSecureStorage mockStorage;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    service = SecureStorageService(storage: mockStorage);
  });

  group('SecureStorageService Tests', () {
    test('writeValue calls storage.write', () async {
      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async => {});

      await service.writeValue('test_key', 'test_value');

      verify(() => mockStorage.write(key: 'test_key', value: 'test_value')).called(1);
    });

    test('readValue returns value from storage.read', () async {
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => 'retrieved_value');

      final result = await service.readValue('test_key');

      expect(result, 'retrieved_value');
      verify(() => mockStorage.read(key: 'test_key')).called(1);
    });

    test('deleteValue calls storage.delete', () async {
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async => {});

      await service.deleteValue('test_key');

      verify(() => mockStorage.delete(key: 'test_key')).called(1);
    });

    test('deleteAll calls storage.deleteAll', () async {
      when(() => mockStorage.deleteAll())
          .thenAnswer((_) async => {});

      await service.deleteAll();

      verify(() => mockStorage.deleteAll()).called(1);
    });

    test('writeValue throws exception on failure', () async {
      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenThrow(Exception('Native Error'));

      expect(() => service.writeValue('k', 'v'), throwsException);
    });
  });
}
