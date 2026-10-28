import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/models/vlm_config.dart';
import 'package:imgcrunch/models/vlm_prompt_preset.dart';

void main() {
  group('VlmPromptPreset', () {
    test('resolves default preset prompts', () {
      expect(
        VlmPromptPreset.description.resolvePrompt(null),
        contains('Describe this image in detail'),
      );
      expect(
        VlmPromptPreset.visualTags.resolvePrompt(null),
        contains('visual keywords and tags'),
      );
      expect(
        VlmPromptPreset.booruTags.resolvePrompt(null),
        contains('Danbooru-style'),
      );
      expect(
        VlmPromptPreset.forensic.resolvePrompt(null),
        contains('Error Level Analysis ELA map'),
      );
    });

    test('custom preset returns custom prompt when provided', () {
      expect(
        VlmPromptPreset.custom.resolvePrompt('my custom instruction'),
        equals('my custom instruction'),
      );
      // Fallback if custom text is empty
      expect(
        VlmPromptPreset.custom.resolvePrompt('   '),
        equals(VlmPromptPreset.description.prompt),
      );
    });

    test('parses from ID safely', () {
      expect(VlmPromptPreset.fromId('description'), equals(VlmPromptPreset.description));
      expect(VlmPromptPreset.fromId('tags'), equals(VlmPromptPreset.visualTags));
      expect(VlmPromptPreset.fromId('visual_tags'), equals(VlmPromptPreset.visualTags));
      expect(VlmPromptPreset.fromId('booru'), equals(VlmPromptPreset.booruTags));
      expect(VlmPromptPreset.fromId('booru_tags'), equals(VlmPromptPreset.booruTags));
      expect(VlmPromptPreset.fromId('forensic'), equals(VlmPromptPreset.forensic));
      expect(VlmPromptPreset.fromId('fornsc'), equals(VlmPromptPreset.forensic));
      expect(VlmPromptPreset.fromId('ela'), equals(VlmPromptPreset.forensic));
      expect(VlmPromptPreset.fromId('custom'), equals(VlmPromptPreset.custom));
      expect(VlmPromptPreset.fromId('unknown_gibberish'), equals(VlmPromptPreset.description));
    });
  });

  group('VlmConfig', () {
    test('has valid defaults', () {
      const config = VlmConfig();
      expect(config.endpoint, equals('http://localhost:11434/v1'));
      expect(config.apiKey, isEmpty);
      expect(config.model, equals('qwen3.5'));
      expect(config.activePreset, equals(VlmPromptPreset.description));
      expect(config.customPrompt, isEmpty);
      expect(config.promptHistory, isEmpty);
      expect(config.effectivePrompt, equals(VlmPromptPreset.description.prompt));
      expect(config.includeForensics, isFalse);
    });

    test('serializes and deserializes cleanly to JSON', () {
      final original = const VlmConfig(
        endpoint: 'https://openrouter.ai/api/v1',
        apiKey: 'sk-secret-key-123',
        model: 'minicpm-v',
        activePreset: VlmPromptPreset.visualTags,
        customPrompt: 'test prompt',
        promptHistory: ['prompt1', 'prompt2'],
        includeForensics: true,
      );

      final jsonStr = original.toJsonString();
      final restored = VlmConfig.fromJsonString(jsonStr);

      expect(restored, equals(original));
      expect(restored.endpoint, equals('https://openrouter.ai/api/v1'));
      expect(restored.apiKey, equals('sk-secret-key-123'));
      expect(restored.model, equals('minicpm-v'));
      expect(restored.activePreset, equals(VlmPromptPreset.visualTags));
      expect(restored.promptHistory, equals(['prompt1', 'prompt2']));
      expect(restored.includeForensics, isTrue);
    });

    test('toggleIncludeForensics flips the boolean flag', () {
      const config = VlmConfig();
      expect(config.includeForensics, isFalse);
      final toggledOn = config.toggleIncludeForensics();
      expect(toggledOn.includeForensics, isTrue);
      final toggledOff = toggledOn.toggleIncludeForensics();
      expect(toggledOff.includeForensics, isFalse);
    });

    test('MRU push adds to front and removes duplicates', () {
      var config = const VlmConfig();
      config = config.pushPromptHistory('first prompt');
      expect(config.promptHistory, equals(['first prompt']));

      config = config.pushPromptHistory('second prompt');
      expect(config.promptHistory, equals(['second prompt', 'first prompt']));

      // Push first prompt again: should move to front without duplicate
      config = config.pushPromptHistory('first prompt');
      expect(config.promptHistory, equals(['first prompt', 'second prompt']));
    });

    test('MRU caps strictly at 5 items', () {
      var config = const VlmConfig();
      for (int i = 1; i <= 8; i++) {
        config = config.pushPromptHistory('prompt $i');
      }

      expect(config.promptHistory.length, equals(5));
      expect(config.promptHistory, equals([
        'prompt 8',
        'prompt 7',
        'prompt 6',
        'prompt 5',
        'prompt 4',
      ]));
    });

    test('MRU ignores empty or whitespace-only prompts', () {
      var config = const VlmConfig(promptHistory: ['valid']);
      config = config.pushPromptHistory('');
      config = config.pushPromptHistory('   ');
      expect(config.promptHistory, equals(['valid']));
    });

    test('clearPromptHistory empties the list', () {
      final config = const VlmConfig(promptHistory: ['a', 'b', 'c']).clearPromptHistory();
      expect(config.promptHistory, isEmpty);
    });
  });
}
