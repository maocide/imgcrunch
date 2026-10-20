import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'mime_utils.dart';

/// Helper utility for reading local images and converting them to
/// standard OpenAI/OpenRouter compliant base64 data URIs.
class VlmVisionHelper {
  const VlmVisionHelper._();

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
  static Future<String> toDataUri(String filePath) async {
    final image = await loadImage(filePath);
    return toDataUriFromBytes(image.bytes, mimeType: image.mimeType);
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
