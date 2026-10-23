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

    testWidgets('unfocuses active EditableText when Escape is pressed', (tester) async {
      final manager = ViewerShortcutManager();

      final textController = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Shortcuts.manager(
              manager: manager,
              child: Actions(
                actions: {},
                child: Column(
                  children: [
                    TextField(
                      controller: textController,
                      focusNode: focusNode,
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

      expect(focusNode.hasFocus, isTrue);

      // Send Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(focusNode.hasFocus, isFalse, reason: 'Escape should defocus the active text field');
    });

    testWidgets('does not ignore shortcuts when a readOnly EditableText has focus', (tester) async {
      bool actionTriggered = false;

      final manager = ViewerShortcutManager();

      final intent = _TestIntent(() {
        actionTriggered = true;
      });

      manager.shortcuts = {
        const SingleActivator(LogicalKeyboardKey.digit1): intent,
      };

      final textController = TextEditingController(text: 'Terminal output');
      final focusNode = FocusNode();

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
                      focusNode: focusNode,
                      readOnly: true,
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

      expect(focusNode.hasFocus, isTrue);

      // Send digit 1
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();

      expect(actionTriggered, isTrue, reason: 'Read-only text must not block viewer shortcuts');
    });
  });
}

class _TestIntent extends Intent {
  const _TestIntent(this.callback);
  final VoidCallback callback;
}
