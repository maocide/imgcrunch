import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/widgets/retro_floppy_disk.dart';

void main() {
  group('RetroFloppyDisk Widget Tests', () {
    testWidgets('renders CustomPaint with correct aspect ratio', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RetroFloppyDisk(size: 100),
            ),
          ),
        ),
      );

      expect(find.byType(RetroFloppyDisk), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      final renderBox = tester.renderObject(find.byType(RetroFloppyDisk)) as RenderBox;
      expect(renderBox.size.width, equals(100.0));
      expect(renderBox.size.height, closeTo(104.0, 0.1));
    });
  });
}
