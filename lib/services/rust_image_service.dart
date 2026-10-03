import 'dart:io';
import 'dart:typed_data';
import '../src/rust/api/ela.dart' as rust_ela;

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
    return await rust_ela.processElaBytes(
      rawBytes: rawBytes,
      scale: scale,
    );
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
}
