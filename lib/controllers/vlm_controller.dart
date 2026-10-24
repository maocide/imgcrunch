import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/vlm_config.dart';
import '../models/vlm_prompt_preset.dart';
import '../services/rust_image_service.dart';
import '../services/storage/config_storage.dart';
import '../services/storage/file_config_storage.dart';
import '../services/vlm/vlm_client.dart';
import 'crunch_state_controller.dart';

/// Controller managing the VLM (Vision Language Model) inspection state,
/// persistence, prompt presets, 5-item MRU history, and streaming execution.
class VlmController extends ChangeNotifier {
  VlmController({
    IConfigStorage? configStorage,
    VlmClient? vlmClient,
    RustImageService? rustService,
  }) : _configStorage = configStorage ?? FileConfigStorage(),
       _vlmClient = vlmClient ?? VlmClient(),
       _rustService = rustService ?? RustImageService.instance;

  final IConfigStorage _configStorage;
  final VlmClient _vlmClient;
  final RustImageService _rustService;

  static const String configFileName = 'vlm_config.json';

  VlmConfig _config = const VlmConfig();
  VlmConfig get config => _config;

  PipelineState<String> _state = const PipelineIdle<String>();
  PipelineState<String> get state => _state;

  String _accumulatedText = '';
  String get accumulatedText => _accumulatedText;

  String _accumulatedReasoning = '';
  String get accumulatedReasoning => _accumulatedReasoning;

  bool get hasReasoning => _accumulatedReasoning.isNotEmpty;

  int _tokenCount = 0;
  int get tokenCount => _tokenCount;

  Duration _elapsedTime = Duration.zero;
  Duration get elapsedTime => _elapsedTime;

  bool _isLoadingConfig = false;
  bool get isLoadingConfig => _isLoadingConfig;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  Stopwatch? _stopwatch;
  final StreamController<String> _tokenStreamCtrl =
      StreamController<String>.broadcast();

  /// Broadcast stream emitting individual token chunks as they arrive from the VLM.
  Stream<String> get tokenStream => _tokenStreamCtrl.stream;

  final StreamController<String> _reasoningStreamCtrl =
      StreamController<String>.broadcast();

  /// Broadcast stream emitting cognitive reasoning chunks (<think>, reasoning_content, delta['reasoning']).
  Stream<String> get reasoningStream => _reasoningStreamCtrl.stream;

  /// Loads configuration from [IConfigStorage].
  Future<void> loadConfig() async {
    _isLoadingConfig = true;
    notifyListeners();

    try {
      final jsonStr = await _configStorage.readConfig(configFileName);
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        _config = VlmConfig.fromJsonString(jsonStr);
      }
    } catch (e) {
      debugPrint('VlmController: Error loading config: $e');
    } finally {
      _isLoadingConfig = false;
      notifyListeners();
    }
  }

  /// Updates the configuration and immediately persists it to storage.
  Future<void> updateConfig(VlmConfig newConfig) async {
    _config = newConfig;
    notifyListeners();
    await _saveConfig();
  }

  /// Selects a prompt preset and saves configuration.
  Future<void> selectPreset(VlmPromptPreset preset) async {
    _config = _config.copyWith(activePreset: preset);
    notifyListeners();
    await _saveConfig();
  }

  /// Updates custom prompt text and marks active preset as [VlmPromptPreset.custom].
  void setCustomPrompt(String text) {
    _config = _config.copyWith(
      customPrompt: text,
      activePreset: VlmPromptPreset.custom,
    );
    notifyListeners();
  }

  /// Pushes a custom prompt to the 5-item MRU history list and saves.
  Future<void> pushPromptHistory(String prompt) async {
    _config = _config.pushPromptHistory(prompt);
    notifyListeners();
    await _saveConfig();
  }

  /// Clears the 5-item MRU prompt history list and saves.
  Future<void> clearPromptHistory() async {
    _config = _config.clearPromptHistory();
    notifyListeners();
    await _saveConfig();
  }

  Future<void> _saveConfig() async {
    try {
      await _configStorage.writeConfig(configFileName, _config.toJsonString());
    } catch (e) {
      debugPrint('VlmController: Error saving config: $e');
    }
  }

  /// Toggles the [includeForensics] state and saves configuration.
  Future<void> toggleIncludeForensics() async {
    _config = _config.toggleIncludeForensics();
    notifyListeners();
    await _saveConfig();
  }

  /// Sets the [includeForensics] state and saves configuration.
  Future<void> setIncludeForensics(bool enabled) async {
    if (_config.includeForensics == enabled) return;
    _config = _config.copyWith(includeForensics: enabled);
    notifyListeners();
    await _saveConfig();
  }

  /// Initiates VLM caption streaming for the specified [imagePath].
  Future<void> crunch({
    required String imagePath,
    String? promptOverride,
    int? elaScale,
    int? strMinLen,
  }) async {
    abort();

    final prompt = (promptOverride != null && promptOverride.trim().isNotEmpty)
        ? promptOverride.trim()
        : _config.effectivePrompt;

    if (prompt.isEmpty) {
      _state = const PipelineError<String>('No prompt specified for VLM.');
      notifyListeners();
      return;
    }

    // Auto-record prompt in MRU history if custom or overridden
    if (_config.activePreset == VlmPromptPreset.custom ||
        promptOverride != null) {
      await pushPromptHistory(prompt);
    }

    _accumulatedText = '';
    _accumulatedReasoning = '';
    _tokenCount = 0;
    _isStreaming = true;
    _stopwatch = Stopwatch()..start();

    Uint8List? elaBytes;
    String? extractedStrings;

    if (_config.includeForensics) {
      _state = const PipelineProcessing<String>(
        'COMPUTING FORENSIC ELA & STRINGS...',
      );
      notifyListeners();

      try {
        elaBytes = await _rustService.generateElaFromFile(
          imagePath,
          scale: elaScale ?? 25,
        );
      } catch (e) {
        debugPrint('VlmController: Error computing ELA for fusion: $e');
      }

      if (!_isStreaming) return;

      try {
        final raw = await _rustService.extractStringsFromFile(
          imagePath,
          minLen: strMinLen ?? 6,
        );
        final lines = raw.split('\n');
        if (lines.length > 80) {
          extractedStrings =
              '${lines.take(80).join('\n')}\n[... truncated ${lines.length - 80} more strings ...]';
        } else {
          extractedStrings = raw;
        }
      } catch (e) {
        debugPrint('VlmController: Error extracting strings for fusion: $e');
      }

      if (!_isStreaming) return;
    }

    _state = PipelineProcessing<String>('CONTACTING VLM (${_config.model})...');
    notifyListeners();

    try {
      final stream = _vlmClient.streamChunks(
        imagePath: imagePath,
        prompt: prompt,
        config: _config,
        elaBytes: elaBytes,
        elaScale: elaScale ?? 25,
        extractedStrings: extractedStrings,
      );

      await for (final chunk in stream) {
        if (chunk.isReasoning) {
          _accumulatedReasoning += chunk.text;
          _reasoningStreamCtrl.add(chunk.text);
        } else {
          _accumulatedText += chunk.text;
          _tokenCount++;
          _tokenStreamCtrl.add(chunk.text);
        }
        _elapsedTime = _stopwatch?.elapsed ?? Duration.zero;
      }

      _stopwatch?.stop();
      _elapsedTime = _stopwatch?.elapsed ?? Duration.zero;
      _isStreaming = false;
      _state = PipelineReady<String>(_accumulatedText);
      notifyListeners();
    } catch (e) {
      if (!_isStreaming) return;
      _stopwatch?.stop();
      _elapsedTime = _stopwatch?.elapsed ?? Duration.zero;
      _isStreaming = false;
      _state = PipelineError<String>(e.toString());
      notifyListeners();
    }
  }

  /// Aborts any in-flight inference stream immediately.
  void abort() {
    _isStreaming = false;
    _vlmClient.abort();
    if (_stopwatch?.isRunning == true) {
      _stopwatch?.stop();
      _elapsedTime = _stopwatch?.elapsed ?? Duration.zero;
    }

    if (_state is PipelineProcessing) {
      if (_accumulatedText.isNotEmpty || _accumulatedReasoning.isNotEmpty) {
        _state = PipelineReady<String>(_accumulatedText);
      } else {
        _state = const PipelineIdle<String>();
      }
      notifyListeners();
    }
  }

  String? _currentImagePath;
  String? get currentImagePath => _currentImagePath;

  /// Called when the active image changes.
  void onImageChanged(String? newPath) {
    if (_currentImagePath == newPath && _state is PipelineIdle<String>) {
      return;
    }
    _currentImagePath = newPath;
    _vlmClient.abort();
    if (_stopwatch?.isRunning == true) {
      _stopwatch?.stop();
    }
    _isStreaming = false;
    _state = const PipelineIdle<String>();
    _accumulatedText = '';
    _accumulatedReasoning = '';
    _tokenCount = 0;
    _elapsedTime = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    abort();
    _tokenStreamCtrl.close();
    _reasoningStreamCtrl.close();
    super.dispose();
  }
}
