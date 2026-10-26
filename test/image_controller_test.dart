import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/controllers/image_controller.dart';
import 'package:imgcrunch/src/rust/frb_generated.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    try {
      await RustLib.init();
    } catch (_) {}
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('imgcrunch_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('ImageController initializes with default sorting state', () {
    final controller = ImageController(enableWatcher: false);
    expect(controller.sortCriterion, PlaylistSortCriterion.name);
    expect(controller.sortDirection, PlaylistSortDirection.ascending);
    expect(controller.sortCriterionLabel, 'NAME');
    expect(controller.sortDirectionArrow, '▲');
    expect(controller.hasImages, isFalse);
    expect(controller.currentDirectory, isNull);
    controller.dispose();
  });

  test('ImageController cycles sort criterion and toggles direction', () {
    final controller = ImageController(enableWatcher: false);

    // Initial: NAME
    expect(controller.sortCriterion, PlaylistSortCriterion.name);

    // Cycle 1: DATE (MODIFIED)
    controller.cycleSortCriterion();
    expect(controller.sortCriterion, PlaylistSortCriterion.modified);
    expect(controller.sortCriterionLabel, 'DATE');

    // Cycle 2: SIZE
    controller.cycleSortCriterion();
    expect(controller.sortCriterion, PlaylistSortCriterion.size);
    expect(controller.sortCriterionLabel, 'SIZE');

    // Cycle 3: back to NAME
    controller.cycleSortCriterion();
    expect(controller.sortCriterion, PlaylistSortCriterion.name);
    expect(controller.sortCriterionLabel, 'NAME');

    // Toggle Direction
    expect(controller.sortDirection, PlaylistSortDirection.ascending);
    expect(controller.sortDirectionArrow, '▲');

    controller.toggleSortDirection();
    expect(controller.sortDirection, PlaylistSortDirection.descending);
    expect(controller.sortDirectionArrow, '▼');

    controller.toggleSortDirection();
    expect(controller.sortDirection, PlaylistSortDirection.ascending);
    expect(controller.sortDirectionArrow, '▲');

    controller.dispose();
  });

  test('ImageController loads directory and preserves active image index on re-sort', () async {
    // Create test image files of varying sizes and names
    final fileA = File('${tempDir.path}/alpha.png');
    final fileB = File('${tempDir.path}/bravo.png');
    final fileC = File('${tempDir.path}/charlie.png');

    await fileA.writeAsBytes(List.filled(300, 0)); // 300 bytes
    await fileB.writeAsBytes(List.filled(100, 0)); // 100 bytes
    await fileC.writeAsBytes(List.filled(200, 0)); // 200 bytes

    final controller = ImageController(enableWatcher: false);
    await controller.loadPath(tempDir.path);

    expect(controller.hasImages, isTrue);
    expect(controller.playlist.length, 3);
    // Ascending Name order: alpha, bravo, charlie
    expect(controller.playlist[0], fileA.path);
    expect(controller.playlist[1], fileB.path);
    expect(controller.playlist[2], fileC.path);

    // Select bravo.png
    controller.jumpTo(1);
    expect(controller.currentPath, fileB.path);

    // Change sort to Size Ascending (bravo 100b, charlie 200b, alpha 300b)
    controller.setSort(
      criterion: PlaylistSortCriterion.size,
      direction: PlaylistSortDirection.ascending,
    );
    await controller.refresh();

    // After re-sort, bravo is at index 0, and currentIndex should automatically pin to bravo!
    expect(controller.playlist[0], fileB.path);
    expect(controller.playlist[1], fileC.path);
    expect(controller.playlist[2], fileA.path);
    expect(controller.currentPath, fileB.path);
    expect(controller.currentIndex, 0);

    controller.dispose();
  });

  test('refresh does not notify listeners when playlist and index are unchanged', () async {
    final fileA = File('${tempDir.path}/alpha.png');
    await fileA.writeAsBytes(List.filled(100, 0));

    final controller = ImageController(enableWatcher: false);
    await controller.loadPath(fileA.path);

    int notifyCount = 0;
    controller.addListener(() {
      notifyCount++;
    });

    await controller.refresh();
    expect(notifyCount, 0, reason: 'Unchanged refresh must not notify listeners');

    controller.dispose();
  });

  test('loadPath is not cancelled by concurrent refresh call', () async {
    final fileA = File('${tempDir.path}/alpha.png');
    final fileB = File('${tempDir.path}/bravo.png');
    await fileA.writeAsBytes(List.filled(100, 0));
    await fileB.writeAsBytes(List.filled(200, 0));

    final controller = ImageController(enableWatcher: false);
    await controller.loadPath(fileA.path);
    expect(controller.currentPath, fileA.path);

    // Concurrently trigger loadPath for fileB and refresh
    final loadFuture = controller.loadPath(fileB.path);
    final refreshFuture = controller.refresh();

    await Future.wait([loadFuture, refreshFuture]);

    // fileB must win and be the currentPath
    expect(controller.currentPath, fileB.path);

    controller.dispose();
  });

  test('ImageController first() and last() navigate to playlist bounds', () async {
    final fileA = File('${tempDir.path}/alpha.png');
    final fileB = File('${tempDir.path}/bravo.png');
    final fileC = File('${tempDir.path}/charlie.png');
    await fileA.writeAsBytes(List.filled(10, 0));
    await fileB.writeAsBytes(List.filled(10, 0));
    await fileC.writeAsBytes(List.filled(10, 0));

    final controller = ImageController(enableWatcher: false);
    await controller.loadPath(tempDir.path);

    expect(controller.currentIndex, 0);

    // Jump to middle, then last()
    controller.jumpTo(1);
    expect(controller.currentIndex, 1);
    controller.last();
    expect(controller.currentIndex, 2);
    expect(controller.currentPath, fileC.path);

    // first()
    controller.first();
    expect(controller.currentIndex, 0);
    expect(controller.currentPath, fileA.path);

    controller.dispose();
  });

  test('ImageController deleteCurrent() removes file from disk and updates playlist', () async {
    final fileA = File('${tempDir.path}/alpha.png');
    final fileB = File('${tempDir.path}/bravo.png');
    final fileC = File('${tempDir.path}/charlie.png');
    await fileA.writeAsBytes(List.filled(10, 0));
    await fileB.writeAsBytes(List.filled(10, 0));
    await fileC.writeAsBytes(List.filled(10, 0));

    final controller = ImageController(enableWatcher: false);
    await controller.loadPath(tempDir.path);
    expect(controller.playlist.length, 3);

    // Select middle file (bravo) and delete it
    controller.jumpTo(1);
    expect(controller.currentPath, fileB.path);

    final success = await controller.deleteCurrent();
    expect(success, isTrue);
    expect(await fileB.exists(), isFalse, reason: 'File should be deleted from disk');
    expect(controller.playlist.length, 2);
    expect(controller.playlist.contains(fileB.path), isFalse);
    // Index 1 now points to charlie
    expect(controller.currentIndex, 1);
    expect(controller.currentPath, fileC.path);

    // Now delete last file (charlie) -> index should clamp to 0 (alpha)
    final success2 = await controller.deleteCurrent();
    expect(success2, isTrue);
    expect(await fileC.exists(), isFalse);
    expect(controller.playlist.length, 1);
    expect(controller.currentIndex, 0);
    expect(controller.currentPath, fileA.path);

    // Delete final file
    final success3 = await controller.deleteCurrent();
    expect(success3, isTrue);
    expect(await fileA.exists(), isFalse);
    expect(controller.playlist.isEmpty, isTrue);
    expect(controller.currentIndex, 0);
    expect(controller.currentPath, isNull);

    // Attempting delete on empty playlist returns false
    final failEmpty = await controller.deleteCurrent();
    expect(failEmpty, isFalse);

    controller.dispose();
  });
}
