import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/controllers/crunch_state_controller.dart';

void main() {
  group('CrunchStateController FSM Tests', () {
    test('initializes with default ViewMode.normal and PipelineIdle for all modes', () {
      final controller = CrunchStateController();
      expect(controller.activeMode, equals(ViewMode.normal));
      expect(controller.elaState, isA<PipelineIdle<dynamic>>());
      expect(controller.asciiState, isA<PipelineIdle<dynamic>>());
      expect(controller.stringsState, isA<PipelineIdle<dynamic>>());
      expect(controller.getStatusMessage(false), contains('PRESS (O) TO LOAD'));
      expect(controller.getStatusMessage(true), equals('Operation done.'));
    });

    test('setMode changes activeMode and notifies listeners', () {
      final controller = CrunchStateController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setMode(ViewMode.ela);
      expect(controller.activeMode, equals(ViewMode.ela));
      expect(notifications, equals(1));

      // Same mode should not trigger spurious notification
      controller.setMode(ViewMode.ela);
      expect(notifications, equals(1));

      controller.setMode(ViewMode.strings);
      expect(controller.activeMode, equals(ViewMode.strings));
      expect(notifications, equals(2));
    });

    test('onImageChanged invalidates cached states and sets new path', () {
      final controller = CrunchStateController();
      controller.onImageChanged('/tmp/test_image.png');

      expect(controller.currentPath, equals('/tmp/test_image.png'));
      expect(controller.elaState, isA<PipelineIdle<dynamic>>());
      expect(controller.asciiState, isA<PipelineIdle<dynamic>>());
      expect(controller.stringsState, isA<PipelineIdle<dynamic>>());
    });

    test('copyActiveContent provides informative message when no image loaded', () async {
      final controller = CrunchStateController();
      final message = await controller.copyActiveContent();
      expect(message, equals('No image loaded to copy'));
    });
  });
}
