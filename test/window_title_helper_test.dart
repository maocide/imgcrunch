import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/utils/window_title_helper.dart';

void main() {
  group('WindowTitleHelper.formatTitle', () {
    test('returns default app name when hasImages is false', () {
      final title = WindowTitleHelper.formatTitle(
        hasImages: false,
        fileName: '',
        currentIndex: 0,
        totalCount: 0,
        scale: 1.0,
      );
      expect(title, equals('imgcrunch'));
    });

    test('formats title with middle dot separator and track brackets', () {
      final title = WindowTitleHelper.formatTitle(
        hasImages: true,
        fileName: 'specimen_01.png',
        currentIndex: 0,
        totalCount: 14,
        scale: 1.0,
      );
      expect(title, equals('imgcrunch · specimen_01.png · [1/14] · 100%'));
    });

    test('formats title correctly with different zoom scales and track indices', () {
      final title = WindowTitleHelper.formatTitle(
        hasImages: true,
        fileName: 'circuit_board.jpg',
        currentIndex: 4,
        totalCount: 10,
        scale: 2.5,
      );
      expect(title, equals('imgcrunch · circuit_board.jpg · [5/10] · 250%'));
    });

    test('handles empty totalCount edge case cleanly', () {
      final title = WindowTitleHelper.formatTitle(
        hasImages: true,
        fileName: 'lone_file.png',
        currentIndex: 0,
        totalCount: 0,
        scale: 0.5,
      );
      expect(title, equals('imgcrunch · lone_file.png · [0/0] · 50%'));
    });
  });
}
