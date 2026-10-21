import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// In-memory raw RGBA pixel buffer providing sub-microsecond pixel and patch sampling.
class PixelBuffer {
  PixelBuffer({
    required this.width,
    required this.height,
    required this.byteData,
  });

  final int width;
  final int height;
  final ByteData byteData;

  /// Loads and decodes an image file into a [PixelBuffer] via Flutter's native codec.
  static Future<PixelBuffer?> loadFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return await loadFromBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Loads and decodes raw image bytes into a [PixelBuffer].
  static Future<PixelBuffer?> loadFromBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;
      return PixelBuffer(
        width: image.width,
        height: image.height,
        byteData: byteData,
      );
    } catch (_) {
      return null;
    }
  }

  /// Samples the [Color] at pixel coordinate ([x], [y]).
  /// Clamps coordinates to valid image bounds.
  Color getPixel(int x, int y) {
    if (width <= 0 || height <= 0) return const Color(0x00000000);
    final clampedX = x.clamp(0, width - 1);
    final clampedY = y.clamp(0, height - 1);
    final offset = (clampedY * width + clampedX) * 4;

    final r = byteData.getUint8(offset);
    final g = byteData.getUint8(offset + 1);
    final b = byteData.getUint8(offset + 2);
    final a = byteData.getUint8(offset + 3);

    return Color.fromARGB(a, r, g, b);
  }

  /// Returns the uppercase hex representation (e.g. `#00E5AA` or `#00E5AAFF`).
  String getHex(int x, int y, {bool includeAlpha = false}) {
    final color = getPixel(x, y);
    final r = (color.r * 255).round().clamp(0, 255);
    final g = (color.g * 255).round().clamp(0, 255);
    final b = (color.b * 255).round().clamp(0, 255);
    final a = (color.a * 255).round().clamp(0, 255);

    final rHex = r.toRadixString(16).padLeft(2, '0').toUpperCase();
    final gHex = g.toRadixString(16).padLeft(2, '0').toUpperCase();
    final bHex = b.toRadixString(16).padLeft(2, '0').toUpperCase();

    if (includeAlpha || a < 255) {
      final aHex = a.toRadixString(16).padLeft(2, '0').toUpperCase();
      return '#$rHex$gHex$bHex$aHex';
    }
    return '#$rHex$gHex$bHex';
  }

  /// Returns the CSS-style RGB representation (e.g. `rgb(0, 229, 170)`).
  String getRgb(int x, int y) {
    final color = getPixel(x, y);
    final r = (color.r * 255).round().clamp(0, 255);
    final g = (color.g * 255).round().clamp(0, 255);
    final b = (color.b * 255).round().clamp(0, 255);
    final a = (color.a * 255).round().clamp(0, 255);

    if (a < 255) {
      return 'rgba($r, $g, $b, ${(a / 255).toStringAsFixed(2)})';
    }
    return 'rgb($r, $g, $b)';
  }

  /// Samples a $(2 \times \text{radius} + 1) \times (2 \times \text{radius} + 1)$ grid of pixels centered at ([centerX], [centerY]).
  /// Used for magnified CRT pixel grid display.
  List<List<Color>> getPatch(int centerX, int centerY, {int radius = 4}) {
    final rows = <List<Color>>[];

    for (int dy = -radius; dy <= radius; dy++) {
      final row = <Color>[];
      for (int dx = -radius; dx <= radius; dx++) {
        row.add(getPixel(centerX + dx, centerY + dy));
      }
      rows.add(row);
    }
    return rows;
  }
}
