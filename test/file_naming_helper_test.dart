import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/utils/file_naming_helper.dart';

void main() {
  group('FileNamingHelper', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_naming_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generates initial candidate when file does not exist', () {
      final source = '${tempDir.path}/specimen.jpg';
      final result = FileNamingHelper.computeIncrementalPath(
        source,
        opTag: 'resized',
        targetExtension: 'png',
      );
      expect(result, equals('${tempDir.path}/specimen_resized.png'));
    });

    test('auto-increments collision counter when file exists', () async {
      final source = '${tempDir.path}/specimen.jpg';
      final file1 = File('${tempDir.path}/specimen_resized.png');
      await file1.writeAsString('dummy');

      final result1 = FileNamingHelper.computeIncrementalPath(
        source,
        opTag: 'resized',
        targetExtension: 'png',
      );
      expect(result1, equals('${tempDir.path}/specimen_resized_1.png'));

      final file2 = File('${tempDir.path}/specimen_resized_1.png');
      await file2.writeAsString('dummy');

      final result2 = FileNamingHelper.computeIncrementalPath(
        source,
        opTag: 'resized',
        targetExtension: 'png',
      );
      expect(result2, equals('${tempDir.path}/specimen_resized_2.png'));
    });

    test('preserves source extension if targetExtension is omitted', () {
      final source = '${tempDir.path}/sample.webp';
      final result = FileNamingHelper.computeIncrementalPath(
        source,
        opTag: 'ela',
        targetExtension: null,
      );
      expect(result, equals('${tempDir.path}/sample_ela.webp'));
    });

    test('strips existing opTag to prevent nested accordion filenames', () async {
      // Starting from an already-resized file: 32_resized.png
      final file0 = File('${tempDir.path}/32_resized.png');
      await file0.writeAsString('dummy');

      final result1 = FileNamingHelper.computeIncrementalPath(
        file0.path,
        opTag: 'resized',
      );
      expect(result1, equals('${tempDir.path}/32_resized_1.png'));

      final file1 = File(result1);
      await file1.writeAsString('dummy');

      // Now pass the incremented file 32_resized_1.png
      final result2 = FileNamingHelper.computeIncrementalPath(
        file1.path,
        opTag: 'resized',
      );
      expect(result2, equals('${tempDir.path}/32_resized_2.png'));

      // Test extreme nested accordion filename: 32_resized_3_resized_resized.png
      final nestedPath = '${tempDir.path}/32_resized_3_resized_resized.png';
      final file2 = File('${tempDir.path}/32_resized_2.png');
      await file2.writeAsString('dummy');

      final resultNested = FileNamingHelper.computeIncrementalPath(
        nestedPath,
        opTag: 'resized',
      );
      expect(resultNested, equals('${tempDir.path}/32_resized_3.png'));
    });
  });
}
