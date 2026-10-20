import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/views/viewer_view.dart';

void main() {
  group('ViewerShortcutManager', () {
    testWidgets('triggers shortcuts normally when no text field has focus', (tester) async {
      bool actionTriggered = false;

      final manager = ViewerShortcutManager();

      final intent = _TestIntent(() {
        actionTriggered = true;
      });

      manager.shortcuts = {
        const SingleActivator(LogicalKeyboardKey.space): intent,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Shortcuts.manager(
            manager: manager,
            child: Actions(
              actions: {
                _TestIntent: CallbackAction<_TestIntent>(
                  onInvoke: (i) => i.callback(),
                ),
              },
              child: const Focus(
                autofocus: true,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(actionTriggered, isTrue, reason: 'Shortcut should fire when no text field is focused');
    });

    testWidgets('automatically ignores shortcuts when an EditableText has focus', (tester) async {
      bool actionTriggered = false;

      final manager = ViewerShortcutManager();

      final intent = _TestIntent(() {
        actionTriggered = true;
      });

      manager.shortcuts = {
        const SingleActivator(LogicalKeyboardKey.space): intent,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): intent,
      };

      final textController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Shortcuts.manager(
              manager: manager,
              child: Actions(
                actions: {
                  _TestIntent: CallbackAction<_TestIntent>(
                    onInvoke: (i) => i.callback(),
                  ),
                },
                child: Column(
                  children: [
                    TextField(
                      controller: textController,
                      autofocus: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure TextField is focused
      expect(FocusManager.instance.primaryFocus, isNotNull);

      // Send space while TextField is focused
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(actionTriggered, isFalse, reason: 'Space should be ignored by viewer shortcuts when TextField is focused');

      // Send Ctrl+V while TextField is focused
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(actionTriggered, isFalse, reason: 'Ctrl+V should be ignored by viewer shortcuts so text paste can operate');
    });
  });
}

class _TestIntent extends Intent {
  const _TestIntent(this.callback);
  final VoidCallback callback;
}
