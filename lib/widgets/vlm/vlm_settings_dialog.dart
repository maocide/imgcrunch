import 'package:flutter/material.dart';
import '../../controllers/vlm_controller.dart';
import '../../models/vlm_config.dart';
import '../../theme/app_theme.dart';
import '../retro_button.dart';
import '../retro_led.dart';
import '../retro_panel.dart';

/// Modal configuration dialog for VLM API connection parameters.
class VlmSettingsDialog extends StatefulWidget {
  const VlmSettingsDialog({
    super.key,
    required this.controller,
  });

  final VlmController controller;

  /// Shows the dialog as a modal barrier.
  static Future<void> show(BuildContext context, VlmController controller) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => VlmSettingsDialog(controller: controller),
    );
  }

  @override
  State<VlmSettingsDialog> createState() => _VlmSettingsDialogState();
}

class _VlmSettingsDialogState extends State<VlmSettingsDialog> {
  late final TextEditingController _endpointCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _modelCtrl;
  bool _obscureKey = true;
  bool _includeForensics = false;

  @override
  void initState() {
    super.initState();
    final cfg = widget.controller.config;
    _endpointCtrl = TextEditingController(text: cfg.endpoint);
    _apiKeyCtrl = TextEditingController(text: cfg.apiKey);
    _modelCtrl = TextEditingController(text: cfg.model);
    _includeForensics = cfg.includeForensics;
  }

  @override
  void dispose() {
    _endpointCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = widget.controller.config.copyWith(
      endpoint: _endpointCtrl.text.trim().isNotEmpty
          ? _endpointCtrl.text.trim()
          : VlmConfig.defaultEndpoint,
      apiKey: _apiKeyCtrl.text.trim(),
      model: _modelCtrl.text.trim().isNotEmpty
          ? _modelCtrl.text.trim()
          : VlmConfig.defaultModel,
      includeForensics: _includeForensics,
    );

    await widget.controller.updateConfig(updated);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: RetroPanel(
          style: RetroPanelStyle.raisedMetallic,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const RetroLed(
                    isActive: true,
                    activeColor: AppTheme.xCopyGreen,
                    size: 9,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'VLM // API CONNECTION CONFIGURATION',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: ctx.wireframeCyan,
                      ),
                    ),
                  ),
                  RetroButton(
                    label: 'X',
                    fontSize: 11,
                    textColor: ctx.wireframeCyanDim,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: ctx.wireframeCyan.withValues(alpha: 0.3)),
              const SizedBox(height: 16),

              // Endpoint field
              _buildFieldLabel('API ENDPOINT URL (OPENAI COMPATIBLE)'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _endpointCtrl,
                hintText: 'e.g. http://localhost:11434/v1 or https://openrouter.ai/api/v1',
              ),
              const SizedBox(height: 14),

              // API Key field
              _buildFieldLabel('API KEY (OPTIONAL FOR LOCAL OLLAMA / VLLM)'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _apiKeyCtrl,
                      hintText: 'sk-...',
                      obscureText: _obscureKey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  RetroButton(
                    label: _obscureKey ? 'SHOW' : 'HIDE',
                    textColor: AppTheme.xCopyAmber,
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Model name field
              _buildFieldLabel('MODEL IDENTIFIER'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _modelCtrl,
                hintText: 'e.g. qwen3.5, qwen2.5-vl, minicpm-v, llava, gpt-4o-mini',
              ),
              const SizedBox(height: 14),

              // Forensic Fusion Telemetry Toggle
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _includeForensics,
                    activeColor: AppTheme.xCopyAmber,
                    checkColor: AppTheme.xCopyCrtBlack,
                    onChanged: (val) {
                      setState(() {
                        _includeForensics = val ?? false;
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _includeForensics = !_includeForensics;
                        });
                      },
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 10),
                          Text(
                            'ATTACH FORENSIC TELEMETRY (ELA + STRINGS)',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.xCopyAmber,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Sends computed ELA difference map and extracted binary strings to VLM for forgery and manipulation analysis.',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: AppTheme.xCopyRivet,
                              letterSpacing: 0.3,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  RetroButton(
                    label: 'CANCEL',
                    textColor: AppTheme.xCopyRivet,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  RetroButton(
                    label: 'SAVE CONFIG',
                    textColor: AppTheme.xCopyGreen,
                    onPressed: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        color: AppTheme.xCopyAmber,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.xCopyCrtBlack,
        border: Border.all(
          color: context.wireframeCyan.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: AppTheme.xCopyGreen,
          letterSpacing: 0.8,
        ),
        cursorColor: AppTheme.xCopyGreen,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: AppTheme.xCopyCyanDim,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
