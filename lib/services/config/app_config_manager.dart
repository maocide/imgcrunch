import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../controllers/image_controller.dart';
import '../../models/app_config.dart';
import '../../models/vlm_config.dart';
import '../storage/config_storage.dart';

/// Central state manager coordinating persistent application settings.
///
/// Backed by [IConfigStorage] to write to `config.json` atomically.
class AppConfigManager extends ChangeNotifier {
  final IConfigStorage _storage;
  AppConfig _config;

  AppConfigManager({
    required IConfigStorage storage,
    AppConfig initialConfig = const AppConfig(),
  })  : _storage = storage,
        _config = initialConfig;

  AppConfig get config => _config;
  IConfigStorage get storage => _storage;

  /// Re-reads configuration from underlying storage.
  Future<void> reload() async {
    try {
      final raw = await _storage.readConfig(AppConfig.configFileName);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _config = AppConfig.fromJson(decoded);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('AppConfigManager: Error reloading config: $e');
    }
  }

  /// Loads configuration from [storage], falling back to defaults if unreadable.
  static Future<AppConfigManager> load(IConfigStorage storage) async {
    try {
      final raw = await storage.readConfig(AppConfig.configFileName);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return AppConfigManager(
            storage: storage,
            initialConfig: AppConfig.fromJson(decoded),
          );
        }
      }
    } catch (e) {
      debugPrint('AppConfigManager: Error loading config: $e');
    }
    return AppConfigManager(storage: storage);
  }

  /// Updates playlist sorting preferences and persists atomically to `config.json`.
  Future<void> updateSort({
    PlaylistSortCriterion? criterion,
    PlaylistSortDirection? direction,
  }) async {
    final nextCriterion = criterion ?? _config.sortCriterion;
    final nextDirection = direction ?? _config.sortDirection;
    if (_config.sortCriterion == nextCriterion &&
        _config.sortDirection == nextDirection) {
      return;
    }

    _config = _config.copyWith(
      sortCriterion: nextCriterion,
      sortDirection: nextDirection,
    );
    notifyListeners();
    await _save();
  }

  /// Updates VLM neural inspection configuration and persists atomically to `config.json`.
  Future<void> updateVlm(VlmConfig vlm) async {
    if (_config.vlm == vlm) return;

    _config = _config.copyWith(vlm: vlm);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      await _storage.writeConfig(
        AppConfig.configFileName,
        _config.toJsonString(),
      );
    } catch (e) {
      debugPrint('AppConfigManager: Error saving config: $e');
    }
  }
}
