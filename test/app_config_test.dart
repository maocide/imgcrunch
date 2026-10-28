import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/controllers/image_controller.dart';
import 'package:imgcrunch/models/app_config.dart';
import 'package:imgcrunch/models/vlm_config.dart';
import 'package:imgcrunch/models/vlm_prompt_preset.dart';
import 'package:imgcrunch/services/config/app_config_manager.dart';
import 'package:imgcrunch/services/storage/in_memory_config_storage.dart';

void main() {
  group('AppConfig Model', () {
    test('default constructor sets standard initial values', () {
      const config = AppConfig();
      expect(config.sortCriterion, equals(PlaylistSortCriterion.name));
      expect(config.sortDirection, equals(PlaylistSortDirection.ascending));
      expect(config.vlm, equals(const VlmConfig()));
    });

    test('toJson and fromJson preserves all fields', () {
      const config = AppConfig(
        sortCriterion: PlaylistSortCriterion.modified,
        sortDirection: PlaylistSortDirection.descending,
        vlm: VlmConfig(
          endpoint: 'http://custom-node:8000/v1',
          model: 'qwen-max-vl',
          activePreset: VlmPromptPreset.visualTags,
        ),
      );

      final json = config.toJson();
      expect(json['sortCriterion'], equals('modified'));
      expect(json['sortDirection'], equals('descending'));
      expect(json['vlm']['model'], equals('qwen-max-vl'));

      final restored = AppConfig.fromJson(json);
      expect(restored, equals(config));
    });

    test('fromJson handles invalid or missing values gracefully', () {
      final config = AppConfig.fromJson({'sortCriterion': 'unknown_junk'});
      expect(config.sortCriterion, equals(PlaylistSortCriterion.name));
      expect(config.sortDirection, equals(PlaylistSortDirection.ascending));
      expect(config.vlm, equals(const VlmConfig()));
    });

    test('fromJsonString handles corrupted string with defaults', () {
      final config = AppConfig.fromJsonString('{{{not valid json');
      expect(config, equals(const AppConfig()));
    });
  });

  group('AppConfigManager', () {
    late InMemoryConfigStorage storage;

    setUp(() {
      storage = InMemoryConfigStorage();
    });

    test('load returns default config when file does not exist', () async {
      final manager = await AppConfigManager.load(storage);
      expect(manager.config, equals(const AppConfig()));
    });

    test('load parses existing config.json correctly', () async {
      const customConfig = AppConfig(
        sortCriterion: PlaylistSortCriterion.size,
        sortDirection: PlaylistSortDirection.descending,
      );
      await storage.writeConfig(
        AppConfig.configFileName,
        customConfig.toJsonString(),
      );

      final manager = await AppConfigManager.load(storage);
      expect(manager.config.sortCriterion, equals(PlaylistSortCriterion.size));
      expect(
        manager.config.sortDirection,
        equals(PlaylistSortDirection.descending),
      );
    });

    test('updateSort modifies memory and persists to config.json', () async {
      final manager = await AppConfigManager.load(storage);

      await manager.updateSort(
        criterion: PlaylistSortCriterion.modified,
        direction: PlaylistSortDirection.descending,
      );

      expect(
        manager.config.sortCriterion,
        equals(PlaylistSortCriterion.modified),
      );
      expect(
        manager.config.sortDirection,
        equals(PlaylistSortDirection.descending),
      );

      final savedRaw = await storage.readConfig(AppConfig.configFileName);
      expect(savedRaw, isNotNull);
      final savedJson = jsonDecode(savedRaw!);
      expect(savedJson['sortCriterion'], equals('modified'));
      expect(savedJson['sortDirection'], equals('descending'));
    });

    test('updateVlm modifies memory and persists nested vlm object', () async {
      final manager = await AppConfigManager.load(storage);

      const newVlm = VlmConfig(
        endpoint: 'http://ai.lab:11434/v1',
        model: 'deepseek-vl',
      );
      await manager.updateVlm(newVlm);

      expect(manager.config.vlm.model, equals('deepseek-vl'));
      final savedRaw = await storage.readConfig(AppConfig.configFileName);
      expect(savedRaw, contains('deepseek-vl'));
    });

    test('ImageController loads initial sort and persists updates', () async {
      const initialConfig = AppConfig(
        sortCriterion: PlaylistSortCriterion.size,
        sortDirection: PlaylistSortDirection.descending,
      );
      final manager = AppConfigManager(
        storage: storage,
        initialConfig: initialConfig,
      );

      final controller = ImageController(
        enableWatcher: false,
        configManager: manager,
      );

      expect(controller.sortCriterion, equals(PlaylistSortCriterion.size));
      expect(
        controller.sortDirection,
        equals(PlaylistSortDirection.descending),
      );

      // Cycle sort criterion and verify it persists
      controller.cycleSortCriterion(); // size -> name
      expect(controller.sortCriterion, equals(PlaylistSortCriterion.name));
      expect(manager.config.sortCriterion, equals(PlaylistSortCriterion.name));

      // Toggle sort direction and verify it persists
      controller.toggleSortDirection(); // descending -> ascending
      expect(
        controller.sortDirection,
        equals(PlaylistSortDirection.ascending),
      );
      expect(
        manager.config.sortDirection,
        equals(PlaylistSortDirection.ascending),
      );
    });
  });
}
