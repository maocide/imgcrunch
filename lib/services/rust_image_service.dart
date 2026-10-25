import 'dart:io';
import 'dart:typed_data';
import '../src/rust/api/ascii.dart' as rust_ascii;
import '../src/rust/api/ela.dart' as rust_ela;
import '../src/rust/api/image_resize.dart' as rust_image_resize;
import '../src/rust/api/playlist.dart' as rust_playlist;
import '../src/rust/api/strings.dart' as rust_strings;

/// Singleton service wrapping all Rust FFI operations for image crunching and forensics.
class RustImageService {
  RustImageService._internal();

  static final RustImageService instance = RustImageService._internal();

  /// Runs Error Level Analysis (ELA) on raw image bytes.
  /// Compresses to JPEG in memory, computes difference, amplifies by [scale],
  /// and returns PNG encoded bytes.
  Future<Uint8List> generateElaFromBytes(
    Uint8List rawBytes, {
    int scale = 25,
  }) async {
    return await rust_ela.processElaBytes(rawBytes: rawBytes, scale: scale);
  }

  /// Convenience method: Reads file at [filePath] and computes ELA.
  Future<Uint8List> generateElaFromFile(
    String filePath, {
    int scale = 25,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Image file not found', filePath);
    }
    final bytes = await file.readAsBytes();
    return await generateElaFromBytes(bytes, scale: scale);
  }

  /// Converts image bytes to an ASCII art text string.
  Future<String> convertToAsciiFromBytes(
    Uint8List rawBytes, {
    int targetWidth = 100,
    double charAspect = 1,
  }) async {
    return await rust_ascii.convertToAscii(
      rawBytes: rawBytes,
      targetWidth: BigInt.from(targetWidth),
      charAspect: charAspect,
    );
  }

  /// Convenience method: Reads file at [filePath] and converts to ASCII art.
  Future<String> convertToAsciiFromFile(
    String filePath, {
    int targetWidth = 100,
    double charAspect = 1,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Image file not found', filePath);
    }
    final bytes = await file.readAsBytes();
    return await convertToAsciiFromBytes(
      bytes,
      targetWidth: targetWidth,
      charAspect: charAspect,
    );
  }

  /// Converts image bytes to an ASCII art PNG bitmap and raw text string tuple.
  Future<(Uint8List, String)> convertToAsciiImageFromBytes(
    Uint8List rawBytes, {
    int targetWidth = 100,
    double charAspect = 1,
  }) async {
    return await rust_ascii.convertToAsciiImage(
      rawBytes: rawBytes,
      targetWidth: BigInt.from(targetWidth),
      charAspect: charAspect,
    );
  }

  /// Convenience method: Reads file at [filePath] and converts to ASCII art PNG bitmap and text.
  Future<(Uint8List, String)> convertToAsciiImageFromFile(
    String filePath, {
    int targetWidth = 100,
    double charAspect = 1,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Image file not found', filePath);
    }
    final bytes = await file.readAsBytes();
    return await convertToAsciiImageFromBytes(
      bytes,
      targetWidth: targetWidth,
      charAspect: charAspect,
    );
  }

  /// Extracts contiguous printable ASCII strings of at least [minLen] characters.
  Future<String> extractStringsFromBytes(
    Uint8List rawBytes, {
    int minLen = 6,
  }) async {
    return await rust_strings.extractStrings(
      rawBytes: rawBytes,
      minLen: BigInt.from(minLen),
    );
  }

  /// Convenience method: Reads file at [filePath] and extracts ASCII strings.
  Future<String> extractStringsFromFile(
    String filePath, {
    int minLen = 6,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Image file not found', filePath);
    }
    final bytes = await file.readAsBytes();
    return await extractStringsFromBytes(bytes, minLen: minLen);
  }

  /// Lists and sorts supported image files in [dirPath] using native Rust.
  /// [order]: 0 = Name, 1 = Size, 2 = Modified.
  /// [direction]: 0 = Ascending, 1 = Descending.
  Future<List<String>> listFiles(
    String dirPath, {
    int order = 0,
    int direction = 0,
  }) async {
    return await rust_playlist.listFiles(
      path: dirPath,
      order: order,
      direction: direction,
    );
  }

  /// Downscales an image preserving aspect ratio using native Rust thumbnail.
  /// Encoded to PNG bytes.
  Future<Uint8List> thumbnailImageFromBytes(
    Uint8List rawBytes, {
    required int maxWidth,
    required int maxHeight,
  }) async {
    return await rust_image_resize.imageThumbnail(
      rawBytes: rawBytes,
      width: maxWidth,
      height: maxHeight,
    );
  }

  /// Convenience method: Reads file at [filePath] and creates a downscaled PNG thumbnail.
  Future<Uint8List> thumbnailImageFromFile(
    String filePath, {
    required int maxWidth,
    required int maxHeight,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Image file not found', filePath);
    }
    final bytes = await file.readAsBytes();
    return await thumbnailImageFromBytes(
      bytes,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  /// Resizes an image to exact [width] and [height] using native Rust Lanczos3 filter.
  /// Encoded to PNG bytes.
  Future<Uint8List> resizeImageFromBytes(
    Uint8List rawBytes, {
    required int width,
    required int height,
  }) async {
    return await rust_image_resize.imageResize(
      rawBytes: rawBytes,
      width: width,
      height: height,
    );
  }
}

