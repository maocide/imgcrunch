import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/controllers/directory_watcher_manager.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('imgcrunch_watcher_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('DirectoryWatcherManager initializes and tracks directory', () {
    int refreshCalls = 0;
    final manager = DirectoryWatcherManager(
      onRefreshRequested: () async {
        refreshCalls++;
      },
      autoRegisterObserver: false,
    );

    expect(manager.currentDirPath, isNull);
    expect(manager.isWatching, isFalse);
    expect(manager.isPaused, isFalse);

    manager.startWatching(tempDir.path);
    expect(manager.currentDirPath, tempDir.path);
    expect(manager.isWatching, isTrue);

    manager.stopWatching();
    expect(manager.currentDirPath, isNull);
    expect(manager.isWatching, isFalse);

    manager.dispose();
    expect(refreshCalls, 0);
  });

  test('DirectoryWatcherManager pauses and resumes on lifecycle transitions', () {
    int refreshCalls = 0;
    final manager = DirectoryWatcherManager(
      onRefreshRequested: () async {
        refreshCalls++;
      },
      autoRegisterObserver: false,
    );

    manager.startWatching(tempDir.path);
    expect(manager.isWatching, isTrue);

    // App goes inactive / hidden / paused
    manager.didChangeAppLifecycleState(AppLifecycleState.inactive);
    expect(manager.isPaused, isTrue);
    expect(manager.isWatching, isFalse);

    // App resumes -> triggers instant catch-up refresh and re-starts watching!
    manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(manager.isPaused, isFalse);
    expect(manager.isWatching, isTrue);
    expect(refreshCalls, 1);

    manager.dispose();
  });
}
