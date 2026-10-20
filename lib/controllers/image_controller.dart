import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/rust_image_service.dart';
import 'directory_watcher_manager.dart';

const List<String> supportedExtensions = [
  '.png',
  '.jpg',
  '.jpeg',
  '.webp',
  '.bmp',
  '.gif',
];

enum PlaylistSortCriterion { name, modified, size }

enum PlaylistSortDirection { ascending, descending }

class ImageController extends ChangeNotifier {
  List<String> _playlist = [];
  int _currentIndex = 0;
  String? _currentDirectory;

  PlaylistSortCriterion _sortCriterion = PlaylistSortCriterion.name;
  PlaylistSortDirection _sortDirection = PlaylistSortDirection.ascending;

  late final DirectoryWatcherManager watcherManager;

  ImageController({
    bool enableWatcher = true,
    bool autoRegisterLifecycle = true,
  }) {
    watcherManager = DirectoryWatcherManager(
      onRefreshRequested: refresh,
      autoRegisterObserver: autoRegisterLifecycle,
    );
    if (!enableWatcher) {
      watcherManager.setWatchingEnabled(false);
    }
  }

  List<String> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  bool get hasImages => _playlist.isNotEmpty;
  String? get currentDirectory => _currentDirectory;

  PlaylistSortCriterion get sortCriterion => _sortCriterion;
  PlaylistSortDirection get sortDirection => _sortDirection;

  String get sortCriterionLabel {
    switch (_sortCriterion) {
      case PlaylistSortCriterion.name:
        return 'NAME';
      case PlaylistSortCriterion.modified:
        return 'DATE';
      case PlaylistSortCriterion.size:
        return 'SIZE';
    }
  }

  String get sortDirectionArrow =>
      _sortDirection == PlaylistSortDirection.ascending ? '▲' : '▼';

  String? get currentPath =>
      hasImages && _currentIndex >= 0 && _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;

  String get currentFileName {
    final path = currentPath;
    if (path == null) return '';
    return path.split(Platform.pathSeparator).last;
  }

  int get _rustOrder {
    switch (_sortCriterion) {
      case PlaylistSortCriterion.name:
        return 0;
      case PlaylistSortCriterion.size:
        return 1;
      case PlaylistSortCriterion.modified:
        return 2;
    }
  }

  int get _rustDirection =>
      _sortDirection == PlaylistSortDirection.ascending ? 0 : 1;

  Future<void> loadPath(String path) async {
    try {
      final fileType = FileSystemEntity.typeSync(path);
      if (fileType == FileSystemEntityType.file) {
        await _loadSingleFileWithSiblings(path);
      } else if (fileType == FileSystemEntityType.directory) {
        await _loadDirectory(path);
      }
    } catch (e) {
      debugPrint('Error inspecting path: $e');
    }
  }

  Future<void> _loadDirectory(String dirPath) async {
    _currentDirectory = dirPath;
    watcherManager.startWatching(dirPath);

    final files = await _scanDirectory(dirPath);
    _playlist = files;
    _currentIndex = 0;
    notifyListeners();
  }

  Future<void> _loadSingleFileWithSiblings(String filePath) async {
    try {
      final file = File(filePath);
      final parentDir = file.parent;
      _currentDirectory = parentDir.path;
      watcherManager.startWatching(parentDir.path);

      final files = await _scanDirectory(parentDir.path);
      if (files.isNotEmpty) {
        _playlist = files;
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

  Future<List<String>> _scanDirectory(String dirPath) async {
    try {
      return await RustImageService.instance.listFiles(
        dirPath,
        order: _rustOrder,
        direction: _rustDirection,
      );
    } catch (e) {
      debugPrint('Rust listFiles failed, falling back to Dart scan: $e');
      return _fallbackScanDirectory(dirPath);
    }
  }

  List<String> _fallbackScanDirectory(String dirPath) {
    try {
      final dir = Directory(dirPath);
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => _isSupported(f.path))
          .map((f) => f.path)
          .toList();

      switch (_sortCriterion) {
        case PlaylistSortCriterion.name:
          files.sort((a, b) {
            final comp = a.toLowerCase().compareTo(b.toLowerCase());
            return _sortDirection == PlaylistSortDirection.ascending
                ? comp
                : -comp;
          });
        case PlaylistSortCriterion.size:
          files.sort((a, b) {
            final aLen = File(a).lengthSync();
            final bLen = File(b).lengthSync();
            final comp = aLen.compareTo(bLen);
            return _sortDirection == PlaylistSortDirection.ascending
                ? comp
                : -comp;
          });
        case PlaylistSortCriterion.modified:
          files.sort((a, b) {
            final aTime = File(a).lastModifiedSync();
            final bTime = File(b).lastModifiedSync();
            final comp = aTime.compareTo(bTime);
            return _sortDirection == PlaylistSortDirection.ascending
                ? comp
                : -comp;
          });
      }
      return files;
    } catch (e) {
      debugPrint('Fallback scan failed: $e');
      return [];
    }
  }

  bool _isSupported(String path) {
    final lower = path.toLowerCase();
    return supportedExtensions.any((ext) => lower.endsWith(ext));
  }

  void cycleSortCriterion() {
    switch (_sortCriterion) {
      case PlaylistSortCriterion.name:
        _sortCriterion = PlaylistSortCriterion.modified;
      case PlaylistSortCriterion.modified:
        _sortCriterion = PlaylistSortCriterion.size;
      case PlaylistSortCriterion.size:
        _sortCriterion = PlaylistSortCriterion.name;
    }
    refresh();
  }

  void toggleSortDirection() {
    _sortDirection =
        _sortDirection == PlaylistSortDirection.ascending
            ? PlaylistSortDirection.descending
            : PlaylistSortDirection.ascending;
    refresh();
  }

  void setSort({
    PlaylistSortCriterion? criterion,
    PlaylistSortDirection? direction,
  }) {
    bool changed = false;
    if (criterion != null && criterion != _sortCriterion) {
      _sortCriterion = criterion;
      changed = true;
    }
    if (direction != null && direction != _sortDirection) {
      _sortDirection = direction;
      changed = true;
    }
    if (changed) {
      refresh();
    }
  }

  Future<void> refresh() async {
    final dir = _currentDirectory;
    if (dir == null) return;

    final activeFile = currentPath;
    final files = await _scanDirectory(dir);

    _playlist = files;
    if (activeFile != null) {
      final newIdx = _playlist.indexOf(activeFile);
      if (newIdx != -1) {
        _currentIndex = newIdx;
      } else {
        _currentIndex =
            _playlist.isNotEmpty ? _currentIndex.clamp(0, _playlist.length - 1) : 0;
      }
    } else {
      _currentIndex = 0;
    }
    notifyListeners();
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

  @override
  void dispose() {
    watcherManager.dispose();
    super.dispose();
  }
}
