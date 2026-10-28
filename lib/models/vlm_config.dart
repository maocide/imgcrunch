import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'vlm_prompt_preset.dart';

/// Configuration and persistence model for the VLM (Vision Language Model) neural inspection mode.
///
/// Holds API connection parameters, selected vision model, active prompt preset,
/// and a 5-item MRU (Most Recently Used) list of custom prompts.
@immutable
class VlmConfig {
  const VlmConfig({
    this.endpoint = defaultEndpoint,
    this.apiKey = '',
    this.model = defaultModel,
    this.activePreset = VlmPromptPreset.description,
    this.customPrompt = '',
    this.promptHistory = const [],
    this.includeForensics = false,
  });

  static const String defaultEndpoint = 'http://localhost:11434/v1';
  static const String defaultModel = 'qwen3.5';
  static const int maxMruHistory = 5;

  /// Base API URL for OpenAI-compatible completions (Ollama, vLLM, OpenRouter, etc.).
  final String endpoint;

  /// Optional API authentication bearer token.
  final String apiKey;

  /// Model identifier to send in the chat completion request.
  final String model;

  /// The currently active prompt preset.
  final VlmPromptPreset activePreset;

  /// Custom prompt text when [activePreset] is [VlmPromptPreset.custom] or being edited.
  final String customPrompt;

  /// Most recently used (MRU) prompt list, capped at [maxMruHistory] items.
  final List<String> promptHistory;

  /// Whether to include computed forensic telemetry (ELA image + extracted binary strings) in VLM payload.
  final bool includeForensics;

  /// Resolves the actual prompt text that will be sent to the VLM engine.
  String get effectivePrompt => activePreset.resolvePrompt(customPrompt);

  /// Toggles the [includeForensics] state.
  VlmConfig toggleIncludeForensics() {
    return copyWith(includeForensics: !includeForensics);
  }

  /// Pushes a custom prompt to the MRU history list.
  ///
  /// Deduplicates existing entries, places the new prompt at index 0,
  /// and caps the list to [maxMruHistory] items.
  VlmConfig pushPromptHistory(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return this;

    final updated = List<String>.from(promptHistory);
    updated.remove(trimmed);
    updated.insert(0, trimmed);
    if (updated.length > maxMruHistory) {
      updated.removeRange(maxMruHistory, updated.length);
    }

    return copyWith(promptHistory: List.unmodifiable(updated));
  }

  /// Clears the MRU prompt history.
  VlmConfig clearPromptHistory() {
    return copyWith(promptHistory: const []);
  }

  VlmConfig copyWith({
    String? endpoint,
    String? apiKey,
    String? model,
    VlmPromptPreset? activePreset,
    String? customPrompt,
    List<String>? promptHistory,
    bool? includeForensics,
  }) {
    return VlmConfig(
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      activePreset: activePreset ?? this.activePreset,
      customPrompt: customPrompt ?? this.customPrompt,
      promptHistory: promptHistory ?? this.promptHistory,
      includeForensics: includeForensics ?? this.includeForensics,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'apiKey': apiKey,
      'model': model,
      'activePreset': activePreset.id,
      'customPrompt': customPrompt,
      'promptHistory': promptHistory,
      'includeForensics': includeForensics,
    };
  }

  factory VlmConfig.fromJson(Map<String, dynamic> json) {
    final rawPreset = json['activePreset'] as String?;
    final rawHistory = json['promptHistory'];

    List<String> history = const [];
    if (rawHistory is List) {
      history = rawHistory
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .take(maxMruHistory)
          .toList(growable: false);
    }

    return VlmConfig(
      endpoint: (json['endpoint'] as String?)?.trim().isNotEmpty == true
          ? (json['endpoint'] as String).trim()
          : defaultEndpoint,
      apiKey: (json['apiKey'] as String?)?.trim() ?? '',
      model: (json['model'] as String?)?.trim().isNotEmpty == true
          ? (json['model'] as String).trim()
          : defaultModel,
      activePreset: VlmPromptPreset.fromId(rawPreset),
      customPrompt: (json['customPrompt'] as String?) ?? '',
      promptHistory: history,
      includeForensics: (json['includeForensics'] as bool?) ?? false,
    );
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  static VlmConfig fromJsonString(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return VlmConfig.fromJson(decoded);
      }
    } catch (_) {}
    return const VlmConfig();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VlmConfig &&
          runtimeType == other.runtimeType &&
          endpoint == other.endpoint &&
          apiKey == other.apiKey &&
          model == other.model &&
          activePreset == other.activePreset &&
          customPrompt == other.customPrompt &&
          listEquals(promptHistory, other.promptHistory);

  @override
  int get hashCode => Object.hash(
        endpoint,
        apiKey,
        model,
        activePreset,
        customPrompt,
        Object.hashAll(promptHistory),
      );
}
