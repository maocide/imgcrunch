import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:imgcrunch/controllers/crunch_state_controller.dart';
import 'package:imgcrunch/controllers/vlm_controller.dart';
import 'package:imgcrunch/models/vlm_config.dart';
import 'package:imgcrunch/models/vlm_prompt_preset.dart';
import 'package:imgcrunch/services/storage/in_memory_config_storage.dart';
import 'package:imgcrunch/services/vlm/vlm_client.dart';

class MockStreamClient extends http.BaseClient {
  MockStreamClient(this._tokens);

  final List<String> _tokens;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final controller = StreamController<List<int>>();

    // Emit tokens as SSE data lines
    scheduleMicrotask(() async {
      for (final t in _tokens) {
        controller.add(
          utf8.encode('data: {"choices":[{"delta":{"content":"$t"}}]}\n\n'),
        );
        await Future.delayed(const Duration(milliseconds: 5));
      }
      controller.add(utf8.encode('data: [DONE]\n\n'));
      await controller.close();
    });

    return http.StreamedResponse(
      controller.stream,
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VlmController', () {
    late InMemoryConfigStorage storage;
    late VlmController controller;

    setUp(() {
      storage = InMemoryConfigStorage();
      controller = VlmController(configStorage: storage);
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state is idle and config is default', () {
      expect(controller.state, isA<PipelineIdle<String>>());
      expect(controller.accumulatedText, isEmpty);
      expect(controller.tokenCount, equals(0));
      expect(controller.config, equals(const VlmConfig()));
    });

    test('loads saved config from storage', () async {
      const savedConfig = VlmConfig(
        endpoint: 'https://openrouter.ai/api/v1',
        model: 'minicpm-v',
        activePreset: VlmPromptPreset.visualTags,
        promptHistory: ['saved tag prompt'],
      );
      await storage.writeConfig(
        VlmController.configFileName,
        savedConfig.toJsonString(),
      );

      await controller.loadConfig();

      expect(controller.config.endpoint, equals('https://openrouter.ai/api/v1'));
      expect(controller.config.model, equals('minicpm-v'));
      expect(controller.config.activePreset, equals(VlmPromptPreset.visualTags));
      expect(controller.config.promptHistory, equals(['saved tag prompt']));
    });

    test('selectPreset updates preset and persists to storage', () async {
      await controller.selectPreset(VlmPromptPreset.booruTags);

      expect(controller.config.activePreset, equals(VlmPromptPreset.booruTags));
      final savedStr = await storage.readConfig(VlmController.configFileName);
      expect(savedStr, isNotNull);
      expect(savedStr, contains('booru_tags'));
    });

    test('setCustomPrompt marks preset as custom', () {
      controller.setCustomPrompt('Analyze lighting');

      expect(controller.config.customPrompt, equals('Analyze lighting'));
      expect(controller.config.activePreset, equals(VlmPromptPreset.custom));
    });

    test('pushPromptHistory updates MRU and persists to storage', () async {
      await controller.pushPromptHistory('Prompt 1');
      await controller.pushPromptHistory('Prompt 2');

      expect(controller.config.promptHistory, equals(['Prompt 2', 'Prompt 1']));
      final savedStr = await storage.readConfig(VlmController.configFileName);
      expect(savedStr, contains('Prompt 2'));
    });

    test('clearPromptHistory clears MRU and persists', () async {
      await controller.pushPromptHistory('Prompt 1');
      expect(controller.config.promptHistory, isNotEmpty);

      await controller.clearPromptHistory();
      expect(controller.config.promptHistory, isEmpty);
    });

    test('crunch streams tokens and transitions to PipelineReady', () async {
      final mockHttpClient = MockStreamClient(['Retro ', 'Amiga ', 'VLM']);
      final vlmClient = VlmClient(httpClient: mockHttpClient);
      final testController = VlmController(
        configStorage: storage,
        vlmClient: vlmClient,
      );

      expect(testController.state, isA<PipelineIdle<String>>());

      // Create a mock stream execution with a valid data URI
      final completer = Completer<void>();
      testController.addListener(() {
        if (testController.state is PipelineReady<String>) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      final tempDir = await testDirectory();
      final imagePath = '${tempDir.path}/test.png';
      await File(imagePath).writeAsBytes([0x89, 0x50, 0x4E, 0x47]);

      await testController.crunch(
        imagePath: imagePath,
        promptOverride: 'Test Prompt',
      );

      expect(testController.state, isA<PipelineReady<String>>());
      expect(testController.accumulatedText, equals('Retro Amiga VLM'));
      expect(testController.tokenCount, equals(3));
      expect(testController.config.promptHistory, contains('Test Prompt'));

      testController.dispose();
      await tempDir.delete(recursive: true);
    });

    test('abort cancels streaming immediately', () async {
      final mockHttpClient = MockStreamClient(['Token 1', 'Token 2']);
      final vlmClient = VlmClient(httpClient: mockHttpClient);
      final testController = VlmController(
        configStorage: storage,
        vlmClient: vlmClient,
      );

      final tempDir = await testDirectory();
      final imagePath = '${tempDir.path}/test.png';
      await File(imagePath).writeAsBytes([0x89, 0x50, 0x4E, 0x47]);

      // Trigger crunch and immediately abort
      final crunchFuture = testController.crunch(imagePath: imagePath);
      testController.abort();
      await crunchFuture;

      expect(testController.isStreaming, isFalse);
      testController.dispose();
      await tempDir.delete(recursive: true);
    });

    test('onImageChanged aborts and resets state to idle', () {
      controller.onImageChanged('/new/path.png');
      expect(controller.state, isA<PipelineIdle<String>>());
      expect(controller.accumulatedText, isEmpty);
      expect(controller.tokenCount, equals(0));
    });
  });

  group('CrunchStateController with VLM', () {
    test('ViewMode.vlm switches mode and reports correct telemetry ticker', () {
      final crunchController = CrunchStateController();
      expect(crunchController.activeMode, equals(ViewMode.normal));

      crunchController.setMode(ViewMode.vlm);
      expect(crunchController.activeMode, equals(ViewMode.vlm));
      expect(
        crunchController.getStatusMessage(true),
        equals('VLM READY. PRESS (CTRL+ENTER) TO CRUNCH.'),
      );

      crunchController.dispose();
    });

    test('copyActiveContent handles VLM ready and idle states', () async {
      final storage = InMemoryConfigStorage();
      final vlmController = VlmController(configStorage: storage);
      final crunchController = CrunchStateController(vlmController: vlmController);

      crunchController.onImageChanged('/test/path.png');
      crunchController.setMode(ViewMode.vlm);

      // In idle state
      final idleMsg = await crunchController.copyActiveContent();
      expect(idleMsg, equals('No VLM caption ready to copy'));

      crunchController.dispose();
    });
  });
}

Future<Directory> testDirectory() async {
  return Directory.systemTemp.createTemp('vlm_ctrl_test_');
}
