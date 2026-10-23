import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/controllers/crunch_state_controller.dart';
import 'package:imgcrunch/controllers/vlm_controller.dart';
import 'package:imgcrunch/models/vlm_config.dart';
import 'package:imgcrunch/models/vlm_prompt_preset.dart';
import 'package:imgcrunch/services/storage/in_memory_config_storage.dart';
import 'package:imgcrunch/views/vlm_view.dart';
import 'package:imgcrunch/widgets/vlm/vlm_settings_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryConfigStorage storage;
  late VlmController vlmController;
  late CrunchStateController crunchController;
  late Directory tempDir;
  late File testImageFile;

  setUp(() async {
    storage = InMemoryConfigStorage();
    vlmController = VlmController(configStorage: storage);
    crunchController = CrunchStateController(vlmController: vlmController);

    tempDir = await Directory.systemTemp.createTemp('vlm_view_test_');
    testImageFile = File('${tempDir.path}/sample.png');
    await testImageFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47]); // PNG header signature
  });

  tearDown(() async {
    crunchController.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('VlmSettingsDialog', () {
    testWidgets('renders configuration fields and saves updates', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VlmSettingsDialog.show(context, vlmController),
                child: const Text('OPEN CFG'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN CFG'));
      await tester.pumpAndSettle();

      expect(find.text('VLM // API CONNECTION CONFIGURATION'), findsOneWidget);
      expect(find.text('API ENDPOINT URL (OPENAI COMPATIBLE)'), findsOneWidget);
      expect(find.text('MODEL IDENTIFIER'), findsOneWidget);

      // Verify default values in textfields
      expect(find.text(VlmConfig.defaultEndpoint), findsOneWidget);
      expect(find.text(VlmConfig.defaultModel), findsOneWidget);

      // Toggle SHOW / HIDE password
      expect(find.text('SHOW'), findsOneWidget);
      await tester.tap(find.text('SHOW'));
      await tester.pumpAndSettle();
      expect(find.text('HIDE'), findsOneWidget);

      // Tap SAVE CONFIG
      await tester.tap(find.text('SAVE CONFIG'));
      await tester.pumpAndSettle();

      expect(find.text('VLM // API CONNECTION CONFIGURATION'), findsNothing);
    });
  });

  group('VlmView', () {
    testWidgets('renders split deck and updates prompt on pill tap', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VlmView(
              imagePath: testImageFile.path,
              crunchController: crunchController,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and status
      expect(find.text('VLM // VISION ANALYSIS'), findsOneWidget);
      expect(find.text('NEURAL VISION READY'), findsOneWidget);

      // Check preset pills & fusion button
      expect(find.text('DESC'), findsOneWidget);
      expect(find.text('TAGS'), findsOneWidget);
      expect(find.text('BOORU'), findsOneWidget);
      expect(find.text('FORNSC'), findsOneWidget);
      expect(find.text('FUSION: OFF'), findsOneWidget);
      expect(find.text('MRU ▼'), findsOneWidget);
      expect(find.text('CRUNCH NEURAL VLM'), findsOneWidget);

      // Initial prompt should be DESC
      expect(
        find.text(VlmPromptPreset.description.prompt),
        findsOneWidget,
      );

      // Tap TAGS pill
      await tester.tap(find.text('TAGS'));
      await tester.pumpAndSettle();

      expect(vlmController.config.activePreset, equals(VlmPromptPreset.visualTags));
      expect(
        find.text(VlmPromptPreset.visualTags.prompt),
        findsOneWidget,
      );

      // Tap BOORU pill
      await tester.tap(find.text('BOORU'));
      await tester.pumpAndSettle();

      expect(vlmController.config.activePreset, equals(VlmPromptPreset.booruTags));
      expect(
        find.text(VlmPromptPreset.booruTags.prompt),
        findsOneWidget,
      );

      // Tap FORNSC pill: activates forensic preset AND turns FUSION ON
      await tester.tap(find.text('FORNSC'));
      await tester.pumpAndSettle();

      expect(vlmController.config.activePreset, equals(VlmPromptPreset.forensic));
      expect(vlmController.config.includeForensics, isTrue);
      expect(find.text('FUSION: ON'), findsOneWidget);
      expect(
        find.text(VlmPromptPreset.forensic.prompt),
        findsOneWidget,
      );

      // Tap FUSION button: toggles it back to OFF
      await tester.tap(find.text('FUSION: ON'));
      await tester.pumpAndSettle();
      expect(vlmController.config.includeForensics, isFalse);
      expect(find.text('FUSION: OFF'), findsOneWidget);

      // Tap CFG button opens settings dialog
      await tester.tap(find.text('CFG'));
      await tester.pumpAndSettle();
      expect(find.text('VLM // API CONNECTION CONFIGURATION'), findsOneWidget);

      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(find.text('VLM // API CONNECTION CONFIGURATION'), findsNothing);
    });
  });
}
