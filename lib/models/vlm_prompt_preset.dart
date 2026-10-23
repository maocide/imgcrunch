/// Available prompt presets for the VLM (Vision Language Model) neural inspection mode.
enum VlmPromptPreset {
  description(
    id: 'description',
    label: 'DESC',
    title: 'Detailed Description',
    prompt:
        'Describe this image in detail, noting visual composition, subjects, textures, colors, lighting, and any readable text.',
  ),
  visualTags(
    id: 'visual_tags',
    label: 'TAGS',
    title: 'Visual Keywords',
    prompt:
        'Provide a concise, comma-separated list of visual keywords and tags describing the subjects, background, style, and mood.',
  ),
  booruTags(
    id: 'booru_tags',
    label: 'BOORU',
    title: 'Danbooru Tags',
    prompt:
        'Generate Danbooru-style lowercase comma-separated tags describing character attributes, outfit, action, pose, background, and artistic style. Example: 1girl, solo, blue_hair, looking_at_viewer, outdoors.',
  ),
  forensic(
    id: 'forensic',
    label: 'FORNSC',
    title: 'Forensic & ELA Inspection',
    prompt:
        'Perform digital forensic inspection. Correlate Image 1 (original) against Image 2 (Error Level Analysis ELA map) and the extracted binary strings. Identify compression boundaries, splice artifacts, clone marks, and metadata indicators of manipulation.',
  ),
  custom(
    id: 'custom',
    label: 'CUSTOM',
    title: 'Custom Prompt',
    prompt: '',
  );

  const VlmPromptPreset({
    required this.id,
    required this.label,
    required this.title,
    required this.prompt,
  });

  final String id;
  final String label;
  final String title;
  final String prompt;

  /// Resolves the effective prompt string given an optional custom prompt override.
  String resolvePrompt(String? customPrompt) {
    if (this == VlmPromptPreset.custom) {
      return (customPrompt != null && customPrompt.trim().isNotEmpty)
          ? customPrompt.trim()
          : VlmPromptPreset.description.prompt;
    }
    return prompt;
  }

  /// Parses a preset from string id or returns [VlmPromptPreset.description] as fallback.
  static VlmPromptPreset fromId(String? id) {
    return switch (id?.toLowerCase().trim()) {
      'visual_tags' || 'tags' => VlmPromptPreset.visualTags,
      'booru_tags' || 'booru' => VlmPromptPreset.booruTags,
      'forensic' || 'fornsc' || 'ela' => VlmPromptPreset.forensic,
      'custom' => VlmPromptPreset.custom,
      _ => VlmPromptPreset.description,
    };
  }
}
