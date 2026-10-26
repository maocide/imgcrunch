import 'dart:io';

/// Standardized file naming and path resolution helper for IMGCRUNCH disk operations.
class FileNamingHelper {
  const FileNamingHelper._();

  /// Computes an auto-incremented, collision-free file path for an operation.
  ///
  /// Example:
  /// - [sourcePath]: `/home/user/specimen.jpg`
  /// - [opTag]: `resized`
  /// - [targetExtension]: `png` (defaults to 'png' if null)
  ///
  /// First checks `/home/user/specimen_resized.png`.
  /// If it exists on disk, checks `/home/user/specimen_resized_1.png`,
  /// `/home/user/specimen_resized_2.png`, etc., until an unused path is found.
  static String computeIncrementalPath(
    String sourcePath, {
    required String opTag,
    String? targetExtension = 'png',
  }) {
    final sep = Platform.pathSeparator;
    final lastSep = sourcePath.lastIndexOf(sep);
    final dir = lastSep != -1 ? sourcePath.substring(0, lastSep) : '';
    final fullFileName =
        lastSep != -1 ? sourcePath.substring(lastSep + 1) : sourcePath;

    final dotIndex = fullFileName.lastIndexOf('.');
    final baseName =
        dotIndex > 0 ? fullFileName.substring(0, dotIndex) : fullFileName;
    final origExt = dotIndex > 0 ? fullFileName.substring(dotIndex + 1) : '';

    // Strip trailing operation markers (e.g. `_resized`, `_resized_1`, `_resized_resized`)
    // so repeated operations on output specimens cleanly increment rather than nesting.
    var cleanBase = baseName;
    final opPattern = RegExp('(?:_${RegExp.escape(opTag)}(?:_\\d+)?)+\$');
    final stripped = baseName.replaceFirst(opPattern, '');
    if (stripped.isNotEmpty) {
      cleanBase = stripped;
    }

    final ext = (targetExtension ?? (origExt.isNotEmpty ? origExt : 'png'))
        .trim()
        .replaceAll('.', '');
    final suffix = ext.isNotEmpty ? '.$ext' : '';

    final dirPrefix = dir.isNotEmpty ? '$dir$sep' : '';
    final initialCandidate = '$dirPrefix${cleanBase}_$opTag$suffix';
    if (!File(initialCandidate).existsSync()) {
      return initialCandidate;
    }

    int counter = 1;
    while (true) {
      final candidate = '$dirPrefix${cleanBase}_${opTag}_$counter$suffix';
      if (!File(candidate).existsSync()) {
        return candidate;
      }
      counter++;
    }
  }
}
