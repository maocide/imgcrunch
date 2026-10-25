import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../rust_image_service.dart';
import 'mime_utils.dart';

/// Helper utility for reading local images and converting them to
/// standard OpenAI/OpenRouter compliant base64 data URIs.
class VlmVisionHelper {
  const VlmVisionHelper._();

  /// Default max dimension (width or height) to prevent token bloat and OOM
  /// when passing high-resolution camera images to Vision-Language Models.
  static const int defaultMaxDimension = 1024;

  /// Loads image bytes from disk and resolves the MIME type.
  static Future<({Uint8List bytes, String mimeType})> loadImage(
    String filePath,
  ) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final mimeType = MimeUtils.resolveImageMimeType(filePath);
    return (bytes: bytes, mimeType: mimeType);
  }

  /// Converts a local image file path to a base64 data URI:
  /// `data:<mime-type>;base64,<payload>`
  ///
  /// If [maxDimension] is specified (default: [defaultMaxDimension]), the image
  /// is downscaled using native Rust fast thumbnailing, preserving aspect ratio.
  static Future<String> toDataUri(
    String filePath, {
    int? maxDimension = defaultMaxDimension,
  }) async {
    final image = await loadImage(filePath);
    if (maxDimension != null) {
      return await toOptimizedDataUriFromBytes(
        image.bytes,
        mimeType: image.mimeType,
        maxDimension: maxDimension,
      );
    }
    return toDataUriFromBytes(image.bytes, mimeType: image.mimeType);
  }

  /// Downscales image bytes using native Rust thumbnailing to fit within [maxDimension],
  /// then formats into a PNG base64 data URI: `data:image/png;base64,...`.
  ///
  /// Falls back gracefully to the original bytes if Rust engine is unavailable
  /// (e.g. during headless unit tests) or if image decoding fails.
  static Future<String> toOptimizedDataUriFromBytes(
    Uint8List bytes, {
    String mimeType = 'image/png',
    int maxDimension = defaultMaxDimension,
  }) async {
    try {
      final downscaled = await RustImageService.instance.thumbnailImageFromBytes(
        bytes,
        maxWidth: maxDimension,
        maxHeight: maxDimension,
      );
      return toDataUriFromBytes(downscaled, mimeType: 'image/png');
    } catch (_) {
      // Graceful fallback if native FFI is uninitialized or decoding fails
      return toDataUriFromBytes(bytes, mimeType: mimeType);
    }
  }

  /// Formats raw image bytes and a MIME type into a base64 data URI string.
  static String toDataUriFromBytes(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) {
    final base64String = base64Encode(bytes);
    return 'data:$mimeType;base64,$base64String';
  }
}

