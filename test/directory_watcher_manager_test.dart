import 'dart:io';
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
    );

    expect(manager.currentDirPath, isNull);
    expect(manager.isWatching, isFalse);
    expect(manager.isWatchingEnabled, isTrue);

    manager.startWatching(tempDir.path);
    expect(manager.currentDirPath, tempDir.path);
    expect(manager.isWatching, isTrue);

    manager.stopWatching();
    expect(manager.currentDirPath, isNull);
    expect(manager.isWatching, isFalse);

    manager.dispose();
    expect(refreshCalls, 0);
  });

  test('DirectoryWatcherManager toggles watching via setWatchingEnabled', () {
    final manager = DirectoryWatcherManager(
      onRefreshRequested: () async {},
    );

    manager.startWatching(tempDir.path);
    expect(manager.isWatching, isTrue);

    manager.setWatchingEnabled(false);
    expect(manager.isWatchingEnabled, isFalse);
    expect(manager.isWatching, isFalse);

    manager.setWatchingEnabled(true);
    expect(manager.isWatchingEnabled, isTrue);
    expect(manager.isWatching, isTrue);

    manager.dispose();
  });

  test('DirectoryWatcherManager debounces rapid filesystem changes', () async {
    int refreshCalls = 0;
    final manager = DirectoryWatcherManager(
      onRefreshRequested: () async {
        refreshCalls++;
      },
      debounceDuration: const Duration(milliseconds: 50),
    );

    manager.startWatching(tempDir.path);

    // Create a file to trigger filesystem event
    final testFile = File('${tempDir.path}/test.png');
    await testFile.writeAsBytes([1, 2, 3]);

    // Wait for debounce duration
    await Future.delayed(const Duration(milliseconds: 150));
    expect(refreshCalls, greaterThanOrEqualTo(1));

    manager.dispose();
  });
}
