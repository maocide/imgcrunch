import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    testWidgets('showDeleteConfirmationDialog returns true on DELETE and false on CANCEL', (
      tester,
    ) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await RetroDialogHelper.showDeleteConfirmationDialog(
                      context,
                      fileName: 'specimen_01.png',
                      filePath: '/media/specimen_01.png',
                    );
                  },
                  child: const Text('TRIGGER DELETE'),
                );
              },
            ),
          ),
        ),
      );

      // 1. Open dialog and cancel
      await tester.tap(find.text('TRIGGER DELETE'));
      await tester.pumpAndSettle();

      expect(find.text('IMGCRUNCH // CONFIRM FILE DELETION'), findsOneWidget);
      expect(find.text('FILE: specimen_01.png'), findsOneWidget);
      expect(find.text('/media/specimen_01.png'), findsOneWidget);

      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('IMGCRUNCH // CONFIRM FILE DELETION'), findsNothing);

      // 2. Open dialog and confirm delete
      await tester.tap(find.text('TRIGGER DELETE'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('IMGCRUNCH // CONFIRM FILE DELETION'), findsNothing);

      // 3. Open dialog and cancel with Escape shortcut
      await tester.tap(find.text('TRIGGER DELETE'));
      await tester.pumpAndSettle();

      expect(find.text('IMGCRUNCH // CONFIRM FILE DELETION'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('IMGCRUNCH // CONFIRM FILE DELETION'), findsNothing);

      // 4. Open dialog and confirm with Delete shortcut
      await tester.tap(find.text('TRIGGER DELETE'));
      await tester.pumpAndSettle();

      expect(find.text('IMGCRUNCH // CONFIRM FILE DELETION'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('IMGCRUNCH // CONFIRM FILE DELETION'), findsNothing);

      // 5. Open dialog and confirm with Enter shortcut
      await tester.tap(find.text('TRIGGER DELETE'));
      await tester.pumpAndSettle();

      expect(find.text('IMGCRUNCH // CONFIRM FILE DELETION'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('IMGCRUNCH // CONFIRM FILE DELETION'), findsNothing);
    });
  });
}
