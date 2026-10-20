import 'config_storage.dart';

/// In-memory implementation of [IConfigStorage] for fast, deterministic unit testing.
class InMemoryConfigStorage implements IConfigStorage {
  InMemoryConfigStorage({this.configDirectoryPath = '/mock/config/imgcrunch'});

  final Map<String, String> _storage = {};

  @override
  final String configDirectoryPath;

  @override
  Future<bool> configExists(String filename) async {
    return _storage.containsKey(filename);
  }

  @override
  Future<String?> readConfig(String filename) async {
    return _storage[filename];
  }

  @override
  Future<void> writeConfig(String filename, String content) async {
    _storage[filename] = content;
  }

  @override
  Future<void> deleteConfig(String filename) async {
    _storage.remove(filename);
  }

  /// Clears all stored in-memory configs.
  void clear() {
    _storage.clear();
  }
}
