import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../controllers/image_controller.dart';
import 'vlm_config.dart';

/// Unified application configuration model for IMGCRUNCH.
///
/// Encapsulates viewer presentation preferences (playlist sort criteria & direction)
/// as well as neural vision terminal (VLM) parameters into a single persisted entity.
@immutable
class AppConfig {
  static const String configFileName = 'config.json';

  final PlaylistSortCriterion sortCriterion;
  final PlaylistSortDirection sortDirection;
  final VlmConfig vlm;

  const AppConfig({
    this.sortCriterion = PlaylistSortCriterion.name,
    this.sortDirection = PlaylistSortDirection.ascending,
    this.vlm = const VlmConfig(),
  });

  AppConfig copyWith({
    PlaylistSortCriterion? sortCriterion,
    PlaylistSortDirection? sortDirection,
    VlmConfig? vlm,
  }) {
    return AppConfig(
      sortCriterion: sortCriterion ?? this.sortCriterion,
      sortDirection: sortDirection ?? this.sortDirection,
      vlm: vlm ?? this.vlm,
    );
  }

  Map<String, dynamic> toJson() => {
    'sortCriterion': sortCriterion.name,
    'sortDirection': sortDirection.name,
    'vlm': vlm.toJson(),
  };

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final rawCriterion = json['sortCriterion'] as String?;
    final rawDirection = json['sortDirection'] as String?;
    final vlmJson = json['vlm'];

    return AppConfig(
      sortCriterion: PlaylistSortCriterion.values.firstWhere(
        (e) => e.name == rawCriterion,
        orElse: () => PlaylistSortCriterion.name,
      ),
      sortDirection: PlaylistSortDirection.values.firstWhere(
        (e) => e.name == rawDirection,
        orElse: () => PlaylistSortDirection.ascending,
      ),
      vlm: vlmJson is Map<String, dynamic>
          ? VlmConfig.fromJson(vlmJson)
          : VlmConfig.fromJson(json),
    );
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  static AppConfig fromJsonString(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return AppConfig.fromJson(decoded);
      }
    } catch (_) {}
    return const AppConfig();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfig &&
          runtimeType == other.runtimeType &&
          sortCriterion == other.sortCriterion &&
          sortDirection == other.sortDirection &&
          vlm == other.vlm;

  @override
  int get hashCode => Object.hash(sortCriterion, sortDirection, vlm);
}
