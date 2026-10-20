import 'package:flutter/services.dart';

/// Helper to format and dispatch window title updates to the desktop window manager
/// (XFCE / GNOME / KDE / Wayland / X11) via the native GTK method channel.
class WindowTitleHelper {
  WindowTitleHelper._();

  static const MethodChannel _channel = MethodChannel('imgcrunch/window');
  static String _lastTitle = '';

  /// Formats the standard telemetry title string.
  static String formatTitle({
    required bool hasImages,
    required String fileName,
    required int currentIndex,
    required int totalCount,
    required double scale,
  }) {
    if (!hasImages) return 'imgcrunch';
    final trackStr = totalCount > 0 ? '${currentIndex + 1}/$totalCount' : '0/0';
    final zoomStr = '${(scale * 100).toInt()}%';
    return 'imgcrunch // TRK: $trackStr // $fileName // $zoomStr';
  }

  /// Sends the formatted title to the native GTK window.
  static Future<void> updateTitle({
    required bool hasImages,
    required String fileName,
    required int currentIndex,
    required int totalCount,
    required double scale,
  }) async {
    final title = formatTitle(
      hasImages: hasImages,
      fileName: fileName,
      currentIndex: currentIndex,
      totalCount: totalCount,
      scale: scale,
    );

    if (title == _lastTitle) return;
    _lastTitle = title;

    try {
      await _channel.invokeMethod('setTitle', title);
    } catch (_) {
      // Ignored on non-desktop platforms or headless test environments
    }
  }
}
