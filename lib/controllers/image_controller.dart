import 'dart:io';
import 'package:flutter/foundation.dart';

const List<String> supportedExtensions = [
  '.png',
  '.jpg',
  '.jpeg',
  '.webp',
  '.bmp',
  '.gif',
];

class ImageController extends ChangeNotifier {
  List<String> _playlist = [];
  int _currentIndex = 0;

  List<String> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  bool get hasImages => _playlist.isNotEmpty;

  String? get currentPath =>
      hasImages && _currentIndex >= 0 && _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;

  String get currentFileName {
    final path = currentPath;
    if (path == null) return '';
    return path.split(Platform.pathSeparator).last;
  }

  void loadPath(String path) {
    try {
      final fileType = FileSystemEntity.typeSync(path);
      if (fileType == FileSystemEntityType.file) {
        _loadSingleFileWithSiblings(path);
      } else if (fileType == FileSystemEntityType.directory) {
        _loadDirectory(path);
      }
    } catch (e) {
      debugPrint('Error inspecting path: $e');
    }
  }

  void _loadDirectory(String dirPath) {
    try {
      final dir = Directory(dirPath);
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => _isSupported(f.path))
          .map((f) => f.path)
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      _playlist = files;
      _currentIndex = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error reading directory: $e');
    }
  }

  void _loadSingleFileWithSiblings(String filePath) {
    try {
      final file = File(filePath);
      final parentDir = file.parent;
      final siblings = parentDir
          .listSync()
          .whereType<File>()
          .where((f) => _isSupported(f.path))
          .map((f) => f.path)
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (siblings.isNotEmpty) {
        _playlist = siblings;
        final targetIndex = _playlist.indexOf(filePath);
        _currentIndex = targetIndex != -1 ? targetIndex : 0;
      } else {
        _playlist = [filePath];
        _currentIndex = 0;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading file siblings: $e');
      _playlist = [filePath];
      _currentIndex = 0;
      notifyListeners();
    }
  }

  bool _isSupported(String path) {
    final lower = path.toLowerCase();
    return supportedExtensions.any((ext) => lower.endsWith(ext));
  }

  void next() {
    if (_playlist.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _playlist.length;
    notifyListeners();
  }

  void previous() {
    if (_playlist.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    notifyListeners();
  }

  void jumpTo(int index) {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}
