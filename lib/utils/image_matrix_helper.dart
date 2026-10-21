import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ImageMatrixHelper {
  ImageMatrixHelper._();

  /// Decodes raw image dimensions from a file asynchronously without rendering.
  static Future<Size?> getImageDimensions(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      // 1. Instant binary header probing (reads only first 64KB, avoids loading 100MB+ for large GIFs)
      final raf = await file.open(mode: FileMode.read);
      try {
        final headerBytes = await raf.read(64 * 1024);
        final headerSize = tryParseHeader(headerBytes);
        if (headerSize != null) {
          return headerSize;
        }
      } finally {
        await raf.close();
      }

      // 2. Fallback to Flutter native codec with 3-second timeout guard
      final bytes = await file.readAsBytes();
      return await getImageDimensionsFromBytes(
        bytes,
      ).timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }

  /// Parses dimensions from the first chunk of raw bytes by reading binary magic headers.
  static Size? tryParseHeader(Uint8List bytes) {
    if (bytes.length < 10) return null;

    // 1. GIF87a / GIF89a (width at bytes 6..7, height at bytes 8..9 in little endian)
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      final w = bytes[6] | (bytes[7] << 8);
      final h = bytes[8] | (bytes[9] << 8);
      if (w > 0 && h > 0) return Size(w.toDouble(), h.toDouble());
    }

    // 2. PNG (\x89PNG\r\n\x1a\n ... IHDR width, height at bytes 16..23 in big endian)
    if (bytes.length >= 24 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      final w =
          (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final h =
          (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      if (w > 0 && h > 0) return Size(w.toDouble(), h.toDouble());
    }

    // 3. BMP ('BM' ... width at 18..21, height at 22..25 in little endian)
    if (bytes.length >= 26 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      final w =
          bytes[18] | (bytes[19] << 8) | (bytes[20] << 16) | (bytes[21] << 24);
      final h =
          (bytes[22] | (bytes[23] << 8) | (bytes[24] << 16) | (bytes[25] << 24))
              .abs();
      if (w > 0 && h > 0) return Size(w.toDouble(), h.toDouble());
    }

    // 4. WEBP (RIFF....WEBP)
    if (bytes.length >= 30 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      // VP8 (lossy)
      if (bytes[12] == 0x56 &&
          bytes[13] == 0x50 &&
          bytes[14] == 0x38 &&
          bytes[15] == 0x20) {
        if (bytes[23] == 0x9D && bytes[24] == 0x01 && bytes[25] == 0x2A) {
          final w = (bytes[26] | (bytes[27] << 8)) & 0x3fff;
          final h = (bytes[28] | (bytes[29] << 8)) & 0x3fff;
          if (w > 0 && h > 0) return Size(w.toDouble(), h.toDouble());
        }
      }
      // VP8L (lossless)
      else if (bytes[12] == 0x56 &&
          bytes[13] == 0x50 &&
          bytes[14] == 0x38 &&
          bytes[15] == 0x4C) {
        if (bytes.length >= 25 && bytes[20] == 0x2F) {
          final b1 = bytes[21];
          final b2 = bytes[22];
          final b3 = bytes[23];
          final b4 = bytes[24];
          final w = 1 + (b1 | ((b2 & 0x3F) << 8));
          final h = 1 + (((b2 >> 6) | (b3 << 2) | ((b4 & 0xF) << 10)));
          if (w > 0 && h > 0) return Size(w.toDouble(), h.toDouble());
        }
      }
      // VP8X (extended)
      else if (bytes[12] == 0x56 &&
          bytes[13] == 0x50 &&
          bytes[14] == 0x38 &&
          bytes[15] == 0x58) {
        final w = 1 + (bytes[24] | (bytes[25] << 8) | (bytes[26] << 16));
        final h = 1 + (bytes[27] | (bytes[28] << 8) | (bytes[29] << 16));
        if (w > 0 && h > 0) return Size(w.toDouble(), h.toDouble());
      }
    }

    // 5. JPEG (0xFF, 0xD8 ... scan markers for SOF0/SOF1/SOF2: 0xFF, 0xC0..0xC2)
    if (bytes.length > 4 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      int offset = 2;
      while (offset + 9 < bytes.length) {
        if (bytes[offset] != 0xFF) break;
        final marker = bytes[offset + 1];
        offset += 2;
        // Standalone markers
        if (marker == 0xD8 ||
            marker == 0xD9 ||
            (marker >= 0xD0 && marker <= 0xD7)) {
          continue;
        }
        if (offset + 2 > bytes.length) break;
        final length = (bytes[offset] << 8) | bytes[offset + 1];
        // SOF0 (0xC0), SOF1 (0xC1), SOF2 (0xC2)
        if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
          if (offset + 7 <= bytes.length) {
            final h = (bytes[offset + 3] << 8) | bytes[offset + 4];
            final w = (bytes[offset + 5] << 8) | bytes[offset + 6];
            if (w > 0 && h > 0) return Size(w.toDouble(), h.toDouble());
          }
        }
        offset += length;
      }
    }

    return null;
  }

  /// Decodes raw image dimensions from byte array using Flutter's native image codec.
  static Future<Size?> getImageDimensionsFromBytes(Uint8List bytes) async {
    try {
      final headerSize = tryParseHeader(bytes);
      if (headerSize != null) return headerSize;

      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      return Size(image.width.toDouble(), image.height.toDouble());
    } catch (_) {
      return null;
    }
  }

  /// Calculates a Matrix4 that fits the image within the given viewport dimensions,
  /// centered, without upscaling if [allowUpscale] is false.
  static Matrix4 calculateFitMatrix({
    required Size imageSize,
    required Size viewportSize,
    bool allowUpscale = false,
  }) {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return Matrix4.identity();
    }
    if (viewportSize.width <= 0 || viewportSize.height <= 0) {
      return Matrix4.identity();
    }

    final scaleX = viewportSize.width / imageSize.width;
    final scaleY = viewportSize.height / imageSize.height;
    double scale = min(scaleX, scaleY);

    if (!allowUpscale && scale > 1.0) {
      scale = 1.0;
    }

    // Centering offsets
    final scaledWidth = imageSize.width * scale;
    final scaledHeight = imageSize.height * scale;
    final dx = (viewportSize.width - scaledWidth) / 2.0;
    final dy = (viewportSize.height - scaledHeight) / 2.0;

    final translation = Matrix4.translationValues(dx, dy, 0.0);
    final scaling = Matrix4.diagonal3Values(scale, scale, scale);
    return translation * scaling;
  }

  /// Calculates a Matrix4 that centers the image at 1:1 true physical pixel scale (100%).
  static Matrix4 calculateActualSizeMatrix({
    required Size imageSize,
    required Size viewportSize,
  }) {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return Matrix4.identity();
    }

    final dx = (viewportSize.width - imageSize.width) / 2.0;
    final dy = (viewportSize.height - imageSize.height) / 2.0;

    return Matrix4.translationValues(dx, dy, 0.0);
  }

  /// Computes a new matrix applying zoom at [focalPoint] by [scaleFactor],
  /// clamped between [minScale] and [maxScale].
  static Matrix4? zoomAt({
    required Matrix4 currentMatrix,
    required Offset focalPoint,
    required double scaleFactor,
    double minScale = 0.02,
    double maxScale = 50.0,
  }) {
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final newScale = currentScale * scaleFactor;
    if (newScale < minScale || newScale > maxScale) return null;

    final t1 = Matrix4.translationValues(focalPoint.dx, focalPoint.dy, 0.0);
    final s = Matrix4.diagonal3Values(scaleFactor, scaleFactor, scaleFactor);
    final t2 = Matrix4.translationValues(-focalPoint.dx, -focalPoint.dy, 0.0);

    return t1 * s * t2 * currentMatrix;
  }

  /// Converts a viewport-space coordinate (e.g. mouse cursor position) to
  /// original image-space pixel coordinate using the inverse of [transformMatrix].
  ///
  /// Returns `null` if the point falls outside the [imageSize] bounds or if
  /// the matrix is not invertible.
  static Point<int>? viewportToImagePixel({
    required Matrix4 transformMatrix,
    required Offset viewportPosition,
    required Size imageSize,
  }) {
    if (imageSize.width <= 0 || imageSize.height <= 0) return null;

    final inverse = Matrix4.tryInvert(transformMatrix);
    if (inverse == null) return null;

    final imagePoint = MatrixUtils.transformPoint(inverse, viewportPosition);
    final x = imagePoint.dx.floor();
    final y = imagePoint.dy.floor();

    if (x < 0 ||
        y < 0 ||
        x >= imageSize.width.toInt() ||
        y >= imageSize.height.toInt()) {
      return null;
    }
    return Point<int>(x, y);
  }
}
