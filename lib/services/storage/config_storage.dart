/// Abstract interface for application configuration persistence.
///
/// Decouples file I/O and OS directory path resolution from domain controllers,
/// enabling portable execution across Linux, Windows, macOS, and mock test environments.
abstract interface class IConfigStorage {
  /// Reads the text content of [filename] in the application config directory.
  /// Returns `null` if the file does not exist.
  Future<String?> readConfig(String filename);

  /// Writes [content] to [filename] in the application config directory.
  /// Implementations should guarantee atomic persistence and secure permissions where possible.
  Future<void> writeConfig(String filename, String content);

  /// Checks whether [filename] exists in the configuration directory.
  Future<bool> configExists(String filename);

  /// Deletes [filename] from the configuration directory if it exists.
  Future<void> deleteConfig(String filename);

  /// The absolute directory path where configuration files are located.
  String get configDirectoryPath;
}
