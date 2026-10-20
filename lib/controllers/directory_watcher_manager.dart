import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';

typedef DirectoryRefreshCallback = Future<void> Function();

/// Manages filesystem watching for the active directory, bound to Flutter's
/// application lifecycle to conserve OS inotify descriptors when inactive.
class DirectoryWatcherManager with WidgetsBindingObserver {
  final DirectoryRefreshCallback onRefreshRequested;
  final Duration debounceDuration;

  String? _currentDirPath;
  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _debounceTimer;
  bool _isPaused = false;
  bool _isWatchingEnabled = true;

  DirectoryWatcherManager({
    required this.onRefreshRequested,
    this.debounceDuration = const Duration(milliseconds: 300),
    bool autoRegisterObserver = true,
  }) {
    if (autoRegisterObserver) {
      try {
        WidgetsBinding.instance.addObserver(this);
      } catch (e) {
        // Fallback for non-widget test harnesses where WidgetsBinding is not bound
        debugPrint('DirectoryWatcherManager: WidgetsBinding not initialized: $e');
      }
    }
  }

  String? get currentDirPath => _currentDirPath;
  bool get isWatching => _subscription != null && !_isPaused;
  bool get isPaused => _isPaused;

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

    if (!_isWatchingEnabled || _isPaused || _currentDirPath == null) {
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resume();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      pause();
    }
  }

  void pause() {
    if (_isPaused) return;
    _isPaused = true;
    _debounceTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    // Catch any changes made while the window was in the background
    onRefreshRequested();
    _setupWatcher();
  }

  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    stopWatching();
  }
}
