import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/widgets/retro_resize_dialog.dart';

void main() {
  group('RetroResizeDialog', () {
    testWidgets('renders initial dimensions and handles preset clicks', (
      tester,
    ) async {
      String? savedPath;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetroResizeDialog(
              imagePath: '/tmp/test_specimen.jpg',
              naturalSize: const Size(2000, 1000),
              onSaved: (path) => savedPath = path,
            ),
          ),
        ),
      );

      // Verify header and spec readouts
      expect(find.text('IMGCRUNCH // RESIZE IMAGE (LANCZOS3)'), findsOneWidget);
      expect(find.text('[2000 × 1000 PX]'), findsOneWidget);
      expect(find.text('2000'), findsOneWidget);
      expect(find.text('1000'), findsOneWidget);
      expect(find.text('100%'), findsNWidgets(2));

      // Click on 50% preset pill
      await tester.tap(find.text('50%'));
      await tester.pumpAndSettle();

      // Check that width and height were halved
      expect(find.text('1000'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('50%'), findsNWidgets(2));

      // Toggle aspect ratio lock
      expect(find.text('LINKED'), findsOneWidget);
      await tester.tap(find.text('LINKED'));
      await tester.pumpAndSettle();
      expect(find.text('UNLINK'), findsOneWidget);
    });

    testWidgets('closes dialog when Escape shortcut is pressed', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => RetroResizeDialog.show(
                context,
                imagePath: '/tmp/dummy.jpg',
                naturalSize: const Size(100, 100),
                onSaved: (_) {},
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.byType(RetroResizeDialog), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(RetroResizeDialog), findsNothing);
    });
  });
}
