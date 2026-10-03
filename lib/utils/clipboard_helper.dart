import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:super_clipboard/super_clipboard.dart';

class ClipboardHelper {
  ClipboardHelper._();

  /// Reads images from system clipboard (PNG, JPEG, WebP, GIF),
  /// saves them as temporary files, and returns their file paths.
  static Future<List<String>> getImagesFromClipboard() async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        log('[ClipboardHelper] Clipboard not available on this platform');
        return [];
      }

      final reader = await clipboard.read();

      if (reader.canProvide(Formats.png)) {
        return await _readAndSaveImage(reader, Formats.png, 'png');
      } else if (reader.canProvide(Formats.jpeg)) {
        return await _readAndSaveImage(reader, Formats.jpeg, 'jpg');
      } else if (reader.canProvide(Formats.webp)) {
        return await _readAndSaveImage(reader, Formats.webp, 'webp');
      } else if (reader.canProvide(Formats.gif)) {
        return await _readAndSaveImage(reader, Formats.gif, 'gif');
      }

      return [];
    } catch (e, stack) {
      log('[ClipboardHelper] Error reading clipboard: $e', stackTrace: stack);
      return [];
    }
  }

  /// Copies raw image bytes directly to system clipboard in PNG format.
  static Future<bool> copyImageBytes(Uint8List bytes) async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) return false;

      final item = DataWriterItem();
      item.add(Formats.png(bytes));
      await clipboard.write([item]);
      return true;
    } catch (e, stack) {
      log('[ClipboardHelper] Error copying image to clipboard: $e', stackTrace: stack);
      return false;
    }
  }

  static Future<List<String>> _readAndSaveImage(
    ClipboardReader reader,
    SimpleFileFormat format,
    String extension,
  ) async {
    final completer = Completer<List<String>>();

    reader.getFile(
      format,
      (file) async {
        try {
          final bytes = await file.readAll();
          final tempDir = await getTemporaryDirectory();
          final fileName =
              'imgcrunch_clipboard_${DateTime.now().millisecondsSinceEpoch}.$extension';
          final tempFile = File('${tempDir.path}/$fileName');

          await tempFile.writeAsBytes(bytes);
          completer.complete([tempFile.path]);
        } catch (e, stack) {
          log('[ClipboardHelper] Error writing clipboard file: $e', stackTrace: stack);
          completer.complete([]);
        }
      },
      onError: (e) {
        log('[ClipboardHelper] Clipboard getFile error: $e');
        completer.complete([]);
      },
    );

    return completer.future;
  }
}
