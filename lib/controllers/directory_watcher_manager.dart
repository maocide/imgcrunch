import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

typedef DirectoryRefreshCallback = Future<void> Function();

/// Manages continuous filesystem watching for the active playlist directory,
/// debouncing native inotify/filesystem events.
class DirectoryWatcherManager {
  final DirectoryRefreshCallback onRefreshRequested;
  final Duration debounceDuration;

  String? _currentDirPath;
  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _debounceTimer;
  bool _isWatchingEnabled = true;

  DirectoryWatcherManager({
    required this.onRefreshRequested,
    this.debounceDuration = const Duration(milliseconds: 300),
  });

  String? get currentDirPath => _currentDirPath;
  bool get isWatching => _subscription != null;
  bool get isWatchingEnabled => _isWatchingEnabled;

  void startWatching(String dirPath) {
    if (_currentDirPath == dirPath && _subscription != null) {
      return;
    }
    _currentDirPath = dirPath;
    _setupWatcher();
  }

  void stopWatching() {
    _debounceTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _currentDirPath = null;
  }

  void setWatchingEnabled(bool enabled) {
    if (_isWatchingEnabled == enabled) return;
    _isWatchingEnabled = enabled;
    if (_isWatchingEnabled) {
      _setupWatcher();
    } else {
      _debounceTimer?.cancel();
      _subscription?.cancel();
      _subscription = null;
    }
  }

  void _setupWatcher() {
    _debounceTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;

    if (!_isWatchingEnabled || _currentDirPath == null) {
      return;
    }

    try {
      final dir = Directory(_currentDirPath!);
      if (!dir.existsSync()) return;

      _subscription = dir.watch().listen(
        (event) => _onFileSystemEvent(event),
        onError: (error) {
          debugPrint('DirectoryWatcher error on $_currentDirPath: $error');
          _subscription?.cancel();
          _subscription = null;
        },
      );
    } catch (e) {
      debugPrint('Failed to start DirectoryWatcher on $_currentDirPath: $e');
    }
  }

  void _onFileSystemEvent(FileSystemEvent event) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      onRefreshRequested();
    });
  }

  void dispose() {
    stopWatching();
  }
}
