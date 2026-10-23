import 'dart:developer';
import 'package:file_picker/file_picker.dart';

class FileDialogHelper {
  FileDialogHelper._();

  static const List<String> supportedImageExtensions = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'bmp',
    'gif',
    'ico',
  ];

  /// Opens a native OS dialog to pick an image file.
  static Future<String?> pickImage({String dialogTitle = 'Open Image'}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: dialogTitle,
        type: FileType.custom,
        allowedExtensions: supportedImageExtensions,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files.single.path;
      }
    } catch (e, stack) {
      log('[FileDialogHelper] Error picking image: $e', stackTrace: stack);
    }
    return null;
  }

  /// Opens a native OS dialog to select a folder/directory.
  static Future<String?> pickDirectory({String dialogTitle = 'Open Folder'}) async {
    try {
      return await FilePicker.platform.getDirectoryPath(
        dialogTitle: dialogTitle,
      );
    } catch (e, stack) {
      log('[FileDialogHelper] Error picking directory: $e', stackTrace: stack);
    }
    return null;
  }

  /// Opens a native OS "Save As" dialog to save a file.
  static Future<String?> saveFile({
    String dialogTitle = 'Save Image As',
    String? defaultFileName,
    List<String>? allowedExtensions,
  }) async {
    try {
      return await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: defaultFileName,
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );
    } catch (e, stack) {
      log('[FileDialogHelper] Error saving file: $e', stackTrace: stack);
    }
    return null;
  }
}
