import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/services/pixel_reader.dart';

void main() {
  group('PixelBuffer Tests', () {
    test('getPixel, getHex, and getRgb return accurate values from raw RGBA data', () {
      // 2x2 image:
      // (0,0): Pure Red (255, 0, 0, 255)
      // (1,0): Pure Green (0, 255, 0, 255)
      // (0,1): Neon Cyan (0, 229, 170, 255)
      // (1,1): Semi-transparent White (255, 255, 255, 128)
      final bytes = Uint8List.fromList([
        255, 0, 0, 255, // (0,0)
        0, 255, 0, 255, // (1,0)
        0, 229, 170, 255, // (0,1)
        255, 255, 255, 128, // (1,1)
      ]);

      final buffer = PixelBuffer(
        width: 2,
        height: 2,
        byteData: ByteData.sublistView(bytes),
      );

      // (0, 0) -> Red
      final pRed = buffer.getPixel(0, 0);
      expect((pRed.r * 255).round(), equals(255));
      expect((pRed.g * 255).round(), equals(0));
      expect((pRed.b * 255).round(), equals(0));
      expect((pRed.a * 255).round(), equals(255));
      expect(buffer.getHex(0, 0), equals('#FF0000'));
      expect(buffer.getRgb(0, 0), equals('rgb(255, 0, 0)'));

      // (0, 1) -> Cyan
      expect(buffer.getHex(0, 1), equals('#00E5AA'));
      expect(buffer.getRgb(0, 1), equals('rgb(0, 229, 170)'));

      // (1, 1) -> Semi-transparent
      expect(buffer.getHex(1, 1), equals('#FFFFFF80'));
      expect(buffer.getRgb(1, 1), contains('rgba(255, 255, 255,'));
    });

    test('getPatch extracts correct radius grid with edge clamping', () {
      final bytes = Uint8List.fromList([
        255, 0, 0, 255,
        0, 255, 0, 255,
        0, 0, 255, 255,
        255, 255, 0, 255,
      ]);

      final buffer = PixelBuffer(
        width: 2,
        height: 2,
        byteData: ByteData.sublistView(bytes),
      );

      // Radius 1 creates a 3x3 grid
      final patch = buffer.getPatch(0, 0, radius: 1);
      expect(patch.length, equals(3));
      expect(patch[0].length, equals(3));

      // Center pixel (1, 1 in patch) is (0, 0) in buffer -> Red
      expect((patch[1][1].r * 255).round(), equals(255));
      expect((patch[1][1].g * 255).round(), equals(0));
    });
  });
}
