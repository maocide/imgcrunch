import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/services/storage/config_storage.dart';
import 'package:imgcrunch/services/storage/file_config_storage.dart';
import 'package:imgcrunch/services/storage/in_memory_config_storage.dart';

void main() {
  group('InMemoryConfigStorage', () {
    late IConfigStorage storage;

    setUp(() {
      storage = InMemoryConfigStorage();
    });

    test('returns null for non-existent file', () async {
      expect(await storage.readConfig('missing.json'), isNull);
      expect(await storage.configExists('missing.json'), isFalse);
    });

    test('writes and reads config content', () async {
      await storage.writeConfig('test.json', '{"key": "value"}');
      expect(await storage.configExists('test.json'), isTrue);
      expect(await storage.readConfig('test.json'), equals('{"key": "value"}'));
    });

    test('deletes existing config', () async {
      await storage.writeConfig('test.json', '{"foo": "bar"}');
      expect(await storage.configExists('test.json'), isTrue);

      await storage.deleteConfig('test.json');
      expect(await storage.configExists('test.json'), isFalse);
      expect(await storage.readConfig('test.json'), isNull);
    });
  });

  group('FileConfigStorage', () {
    late Directory tempDir;
    late FileConfigStorage storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('imgcrunch_cfg_test_');
      storage = FileConfigStorage(customDirectoryPath: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('resolves custom directory path', () {
      expect(storage.configDirectoryPath, equals(tempDir.path));
    });

    test('writes and reads file atomically', () async {
      const filename = 'vlm_config.json';
      const content = '{"model": "qwen2.5-vl"}';

      expect(await storage.configExists(filename), isFalse);
      expect(await storage.readConfig(filename), isNull);

      await storage.writeConfig(filename, content);

      expect(await storage.configExists(filename), isTrue);
      final read = await storage.readConfig(filename);
      expect(read, equals(content));

      // Ensure no leftover temp files exist
      final tmpFile = File('${tempDir.path}/$filename.tmp');
      expect(await tmpFile.exists(), isFalse);
    });

    test('deletes file from disk', () async {
      const filename = 'to_delete.json';
      await storage.writeConfig(filename, 'test data');
      expect(await storage.configExists(filename), isTrue);

      await storage.deleteConfig(filename);
      expect(await storage.configExists(filename), isFalse);
      expect(await storage.readConfig(filename), isNull);
    });

    test('resolves default OS paths without crashing', () {
      final defaultPath = FileConfigStorage.resolveDefaultConfigDir();
      expect(defaultPath, isNotEmpty);
      expect(defaultPath, contains('imgcrunch'));
    });
  });
}
