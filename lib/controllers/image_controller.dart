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
  '.ico',
];

enum PlaylistSortCriterion { name, modified, size }

enum PlaylistSortDirection { ascending, descending }

class ImageController extends ChangeNotifier {
  List<String> _playlist = [];
  int _currentIndex = 0;
  String? _currentDirectory;
  int _operationId = 0;
  bool _isLoadingPath = false;

  PlaylistSortCriterion _sortCriterion = PlaylistSortCriterion.name;
  PlaylistSortDirection _sortDirection = PlaylistSortDirection.ascending;

  late final DirectoryWatcherManager watcherManager;

  ImageController({
    bool enableWatcher = true,
  }) {
    watcherManager = DirectoryWatcherManager(
      onRefreshRequested: refresh,
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
    _isLoadingPath = true;
    try {
      final fileType = FileSystemEntity.typeSync(path);
      if (fileType == FileSystemEntityType.file) {
        await _loadSingleFileWithSiblings(path);
      } else if (fileType == FileSystemEntityType.directory) {
        await _loadDirectory(path);
      }
    } catch (e) {
      debugPrint('Error inspecting path: $e');
    } finally {
      _isLoadingPath = false;
    }
  }

  Future<void> _loadDirectory(String dirPath) async {
    _operationId++;
    final opId = _operationId;
    _currentDirectory = dirPath;
    watcherManager.startWatching(dirPath);

    final files = await _scanDirectory(dirPath);
    if (opId == _operationId) {
      _playlist = files;
      _currentIndex = 0;
      notifyListeners();
    }
  }

  Future<void> _loadSingleFileWithSiblings(String filePath) async {
    try {
      _operationId++;
      final opId = _operationId;
      final file = File(filePath);
      final parentDir = file.parent;
      _currentDirectory = parentDir.path;
      watcherManager.startWatching(parentDir.path);

      final files = await _scanDirectory(parentDir.path);

      if (opId != _operationId) return;

      if (files.isNotEmpty) {
        _playlist = files;
        final targetFile = File(filePath).absolute.path;
        int targetIndex = _playlist.indexOf(filePath);
        if (targetIndex == -1) {
          targetIndex = _playlist.indexWhere((p) {
            try {
              return File(p).absolute.path == targetFile;
            } catch (_) {
              return false;
            }
          });
        }

        if (targetIndex != -1) {
          _currentIndex = targetIndex;
        } else {
          // File wasn't in scanned list (e.g. extension filter or symlink) - ensure it is in the playlist!
          _playlist.insert(0, filePath);
          _currentIndex = 0;
        }
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
    _sortDirection = _sortDirection == PlaylistSortDirection.ascending
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
    if (_isLoadingPath) return;
    final dir = _currentDirectory;
    if (dir == null) return;

    _operationId++;
    final opId = _operationId;

    final activeFile = currentPath;
    final files = await _scanDirectory(dir);

    if (opId != _operationId || _isLoadingPath) return;

    int newIdx = 0;
    if (activeFile != null) {
      final canonicalActive = File(activeFile).absolute.path;
      newIdx = files.indexOf(activeFile);
      if (newIdx == -1) {
        newIdx = files.indexWhere((p) {
          try {
            return File(p).absolute.path == canonicalActive;
          } catch (_) {
            return false;
          }
        });
      }
      if (newIdx == -1) {
        if (File(activeFile).existsSync()) {
          files.insert(0, activeFile);
          newIdx = 0;
        } else {
          newIdx = files.isNotEmpty
              ? _currentIndex.clamp(0, files.length - 1)
              : 0;
        }
      }
    }

    final hasChanged = !listEquals(_playlist, files) || _currentIndex != newIdx;
    _playlist = files;
    _currentIndex = newIdx;

    if (hasChanged) {
      notifyListeners();
    }
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
