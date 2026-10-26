import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/widgets/retro_pixel_loupe.dart';

void main() {
  group('RetroPixelLoupe Widget Tests', () {
    testWidgets('renders pixel coordinates, hex code, RGB readout, and grid canvas', (tester) async {
      // 9x9 patch of solid red
      final patch = List.generate(
        9,
        (_) => List.generate(9, (_) => const Color(0xFFFF0055)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                RetroPixelLoupe(
                  pixelCoordinates: const Point(42, 108),
                  color: const Color(0xFFFF0055),
                  hexCode: '#FF0055',
                  rgbText: 'rgb(255, 0, 85)',
                  patch: patch,
                  screenPosition: const Offset(100, 100),
                  viewportSize: const Size(800, 600),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify text elements
      expect(find.text('LOUPE 9x9'), findsOneWidget);
      expect(find.text('P: 42,108'), findsOneWidget);
      expect(find.text('#FF0055'), findsOneWidget);
      expect(find.text('RGB: rgb(255, 0, 85)'), findsOneWidget);
      expect(find.text('X: 42 Y: 108'), findsOneWidget);
      expect(find.text('[CLICK] COPY'), findsOneWidget);

      // Verify CustomPaint is present for grid
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('flips position when near viewport right and bottom edges', (tester) async {
      final patch = List.generate(
        9,
        (_) => List.generate(9, (_) => const Color(0xFF00E5AA)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                RetroPixelLoupe(
                  pixelCoordinates: const Point(790, 590),
                  color: const Color(0xFF00E5AA),
                  hexCode: '#00E5AA',
                  rgbText: 'rgb(0, 229, 170)',
                  patch: patch,
                  screenPosition: const Offset(750, 550),
                  viewportSize: const Size(800, 600),
                ),
              ],
            ),
          ),
        ),
      );

      final positionedFinder = find.byType(Positioned);
      expect(positionedFinder, findsOneWidget);

      final Positioned positioned = tester.widget(positionedFinder);
      // Because screenPosition is (750, 550) in an (800, 600) viewport,
      // 750 + loupeWidth > 788 -> flips left: 750 - loupeWidth - 22
      // 550 + 175 > 588 -> flips top: 550 - 175 - 22 = 353
      final expectedLeft = 750 - RetroPixelLoupe.loupeWidth - RetroPixelLoupe.cursorOffset;
      expect(positioned.left, equals(expectedLeft));
      expect(positioned.top, equals(353.0));
    });
  });
}
