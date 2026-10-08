import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/utils/image_matrix_helper.dart';

void main() {
  group('ImageMatrixHelper Tests', () {
    test('calculateFitMatrix scales to fit container without exceeding bounds', () {
      const imageSize = Size(1000, 500); // 2:1 aspect ratio
      const viewportSize = Size(500, 500);

      final matrix = ImageMatrixHelper.calculateFitMatrix(
        imageSize: imageSize,
        viewportSize: viewportSize,
      );

      final scale = matrix.getMaxScaleOnAxis();
      // Scale should be 500 / 1000 = 0.5
      expect(scale, closeTo(0.5, 0.001));

      // Image width scaled is 250, dx is (500 - 250) / 2 = 125?
      // Wait: 1000 * 0.5 = 500, height scaled is 500 * 0.5 = 250
      // dx is (500 - 500) / 2 = 0, dy is (500 - 250) / 2 = 125
      expect(matrix.storage[12], closeTo(0.0, 0.001)); // dx
      expect(matrix.storage[13], closeTo(125.0, 0.001)); // dy
    });

    test('calculateActualSizeMatrix centers at 100% scale', () {
      const imageSize = Size(400, 300);
      const viewportSize = Size(800, 600);

      final matrix = ImageMatrixHelper.calculateActualSizeMatrix(
        imageSize: imageSize,
        viewportSize: viewportSize,
      );

      final scale = matrix.getMaxScaleOnAxis();
      expect(scale, closeTo(1.0, 0.001));

      // dx = (800 - 400) / 2 = 200, dy = (600 - 300) / 2 = 150
      expect(matrix.storage[12], closeTo(200.0, 0.001));
      expect(matrix.storage[13], closeTo(150.0, 0.001));
    });

    test('zoomAt scales around focal point correctly', () {
      final initialMatrix = Matrix4.identity();
      const focalPoint = Offset(100, 100);

      final zoomed = ImageMatrixHelper.zoomAt(
        currentMatrix: initialMatrix,
        focalPoint: focalPoint,
        scaleFactor: 2.0,
      );

      expect(zoomed, isNotNull);
      expect(zoomed!.getMaxScaleOnAxis(), closeTo(2.0, 0.001));
    });

    test('tryParseHeader decodes GIF89a dimensions from raw header bytes', () {
      // GIF89a with 640x480: 640 = 0x0280 (80 02), 480 = 0x01E0 (E0 01)
      final gifBytes = [
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // 'GIF89a'
        0x80, 0x02, // 640
        0xE0, 0x01, // 480
      ];
      final size = ImageMatrixHelper.tryParseHeader(
        Uint8List.fromList(gifBytes),
      );
      expect(size, const Size(640, 480));
    });

    test('tryParseHeader decodes PNG dimensions from IHDR chunk', () {
      // PNG: \x89PNG\r\n\x1a\n + chunk len + IHDR + width(1920) + height(1080)
      final pngBytes = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // magic
        0x00, 0x00, 0x00, 0x0D, // chunk length 13
        0x49, 0x48, 0x44, 0x52, // 'IHDR'
        0x00, 0x00, 0x07, 0x80, // width 1920
        0x00, 0x00, 0x04, 0x38, // height 1080
      ];
      final size = ImageMatrixHelper.tryParseHeader(
        Uint8List.fromList(pngBytes),
      );
      expect(size, const Size(1920, 1080));
    });

    test('tryParseHeader returns null for corrupted/unrecognized bytes', () {
      final garbage = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      expect(ImageMatrixHelper.tryParseHeader(garbage), isNull);
    });
  });
}
