import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/utils/retro_dialog_helper.dart';

void main() {
  group('RetroDialogHelper Tests', () {
    testWidgets('showHelpDialog renders command reference and closes on tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => RetroDialogHelper.showHelpDialog(context),
                  child: const Text('OPEN HELP'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN HELP'));
      await tester.pumpAndSettle();

      expect(find.text('IMGCRUNCH // COMMAND REFERENCE'), findsOneWidget);
      expect(find.text('1 / 2 / 3 / 4 / 5'), findsOneWidget);
      expect(find.text('CLOSE'), findsOneWidget);

      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();

      expect(find.text('IMGCRUNCH // COMMAND REFERENCE'), findsNothing);
    });

    testWidgets('showOpenPathDialog submits path on OPEN button press', (
      tester,
    ) async {
      String? submittedPath;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed:
                      () => RetroDialogHelper.showOpenPathDialog(
                        context,
                        onPathSubmitted: (path) => submittedPath = path,
                      ),
                  child: const Text('OPEN PATH DIALOG'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN PATH DIALOG'));
      await tester.pumpAndSettle();

      expect(find.text('OPEN FILE OR DIRECTORY'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '/tmp/retro_test.png');
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(submittedPath, '/tmp/retro_test.png');
      expect(find.text('OPEN FILE OR DIRECTORY'), findsNothing);
    });
  });
}
