/// Resolves MIME types for image formats based on file extensions.
class MimeUtils {
  const MimeUtils._();

  /// Resolves the MIME type for an image based on its file extension.
  /// Falls back to `image/jpeg` if unknown or missing.
  static String resolveImageMimeType(String filePath) {
    final dotIndex = filePath.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == filePath.length - 1) {
      return 'image/jpeg';
    }

    final ext = filePath.substring(dotIndex + 1).toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'bmp' => 'image/bmp',
      'avif' => 'image/avif',
      'tiff' || 'tif' => 'image/tiff',
      _ => 'image/jpeg',
    };
  }
}
