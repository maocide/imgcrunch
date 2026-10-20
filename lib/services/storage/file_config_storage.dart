import 'dart:io';
import 'package:flutter/foundation.dart';
import 'config_storage.dart';

/// Platform-aware file storage implementing [IConfigStorage].
///
/// Follows XDG Base Directory specification on Linux (`~/.config/imgcrunch`),
/// Roaming AppData on Windows (`%APPDATA%/imgcrunch`), and Application Support on macOS.
///
/// Implements atomic write semantics (via `.tmp` files) and applies POSIX `0600` permissions
/// on Linux/macOS to protect sensitive credentials (e.g. LLM API keys).
class FileConfigStorage implements IConfigStorage {
  FileConfigStorage({this.customDirectoryPath});

  final String? customDirectoryPath;

  @override
  String get configDirectoryPath {
    if (customDirectoryPath != null && customDirectoryPath!.isNotEmpty) {
      return customDirectoryPath!;
    }
    return resolveDefaultConfigDir();
  }

  /// Resolves the default configuration directory based on the host operating system.
  static String resolveDefaultConfigDir() {
    if (Platform.isLinux) {
      final xdg = Platform.environment['XDG_CONFIG_HOME'];
      if (xdg != null && xdg.trim().isNotEmpty) {
        return '$xdg/imgcrunch';
      }
      final home = Platform.environment['HOME'] ?? '.';
      return '$home/.config/imgcrunch';
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.trim().isNotEmpty) {
        return '$appData/imgcrunch';
      }
      final userProfile = Platform.environment['USERPROFILE'] ?? '.';
      return '$userProfile/.config/imgcrunch';
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '.';
      return '$home/Library/Application Support/imgcrunch';
    } else {
      final home = Platform.environment['HOME'] ?? '.';
      return '$home/.config/imgcrunch';
    }
  }

  File _resolveFile(String filename) {
    return File('$configDirectoryPath/$filename');
  }

  @override
  Future<bool> configExists(String filename) async {
    return _resolveFile(filename).exists();
  }

  @override
  Future<String?> readConfig(String filename) async {
    final file = _resolveFile(filename);
    if (!await file.exists()) {
      return null;
    }
    try {
      return await file.readAsString();
    } catch (e) {
      debugPrint('FileConfigStorage: Error reading $filename: $e');
      return null;
    }
  }

  @override
  Future<void> writeConfig(String filename, String content) async {
    final dir = Directory(configDirectoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      // On POSIX, secure the directory itself with 0700
      if (!Platform.isWindows) {
        try {
          await Process.run('chmod', ['700', dir.path]);
        } catch (_) {}
      }
    }

    final targetFile = _resolveFile(filename);
    final tmpFile = File('${targetFile.path}.tmp');

    // Write content to temp file with immediate flush
    await tmpFile.writeAsString(content, flush: true);

    // On POSIX, restrict permissions to 0600 (owner read/write only)
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['600', tmpFile.path]);
      } catch (_) {}
    }

    // Atomically rename temp file to target file
    await tmpFile.rename(targetFile.path);
  }

  @override
  Future<void> deleteConfig(String filename) async {
    final file = _resolveFile(filename);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
