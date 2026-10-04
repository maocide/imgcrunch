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
      final bytes = await file.readAsBytes();
      return await getImageDimensionsFromBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Decodes raw image dimensions from byte array using Flutter's native image codec.
  static Future<Size?> getImageDimensionsFromBytes(Uint8List bytes) async {
    try {
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
}
