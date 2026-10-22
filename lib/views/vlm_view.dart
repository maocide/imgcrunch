import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/crunch_state_controller.dart';
import '../controllers/vlm_controller.dart';
import '../models/vlm_prompt_preset.dart';
import '../theme/app_theme.dart';
import '../widgets/retro_button.dart';
import '../widgets/retro_led.dart';
import '../widgets/retro_panel.dart';
import '../widgets/vlm/vlm_settings_dialog.dart';

/// Dedicated split-deck view for Mode 5: VLM Neural Inspection.
///
/// Features an interactive image viewport on the left and a phosphor CRT terminal,
/// prompt pills, MRU selector, and streaming execution deck on the right.
class VlmView extends StatefulWidget {
  const VlmView({
    super.key,
    required this.imagePath,
    required this.crunchController,
    this.naturalSize,
  });

  final String imagePath;
  final CrunchStateController crunchController;
  final Size? naturalSize;

  @override
  State<VlmView> createState() => _VlmViewState();
}

class _VlmViewState extends State<VlmView> {
  late final TextEditingController _promptTextCtrl;
  late final TextEditingController _terminalTextCtrl;
  final ScrollController _terminalScrollCtrl = ScrollController();
  final FocusNode _promptFocusNode = FocusNode();
  final FocusNode _terminalFocusNode = FocusNode();
  StreamSubscription<String>? _tokenStreamSub;

  VlmController get _vlmCtrl => widget.crunchController.vlmController;

  @override
  void initState() {
    super.initState();
    _promptTextCtrl = TextEditingController(
      text: _vlmCtrl.config.effectivePrompt,
    );
    _terminalTextCtrl = TextEditingController(text: _vlmCtrl.accumulatedText);
    _vlmCtrl.addListener(_onVlmStateChanged);
    _tokenStreamSub = _vlmCtrl.tokenStream.listen(_onTokenReceived);
  }

  void _onTokenReceived(String token) {
    if (!mounted) return;
    final current = _terminalTextCtrl.text;
    _terminalTextCtrl.value = TextEditingValue(
      text: current + token,
      selection: TextSelection.collapsed(offset: current.length + token.length),
    );
    if (_terminalScrollCtrl.hasClients) {
      _terminalScrollCtrl.animateTo(
        _terminalScrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 30),
        curve: Curves.easeOut,
      );
    }
    // Update button states if needed
    if (current.isEmpty && token.isNotEmpty) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tokenStreamSub?.cancel();
    _vlmCtrl.removeListener(_onVlmStateChanged);
    _promptTextCtrl.dispose();
    _terminalTextCtrl.dispose();
    _terminalScrollCtrl.dispose();
    _promptFocusNode.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

  void _onVlmStateChanged() {
    if (!mounted) return;
    if (_vlmCtrl.accumulatedText.isEmpty && _vlmCtrl.state is PipelineIdle) {
      if (_terminalTextCtrl.text.isNotEmpty) {
        _terminalTextCtrl.clear();
      }
    } else if (_vlmCtrl.state is PipelineReady &&
        _terminalTextCtrl.text.isEmpty) {
      _terminalTextCtrl.text = _vlmCtrl.accumulatedText;
    }
    setState(() {});
  }

  void _selectPreset(VlmPromptPreset preset) {
    _vlmCtrl.selectPreset(preset);
    _promptTextCtrl.text = preset.prompt;
    setState(() {});
  }

  void _selectMruPrompt(String prompt) {
    _vlmCtrl.setCustomPrompt(prompt);
    _promptTextCtrl.text = prompt;
    setState(() {});
  }

  Future<void> _crunch() async {
    final endpoint = _vlmCtrl.config.endpoint.trim();
    if (endpoint.isEmpty) {
      await VlmSettingsDialog.show(context, _vlmCtrl);
      return;
    }

    _terminalTextCtrl.clear();

    await _vlmCtrl.crunch(
      imagePath: widget.imagePath,
      promptOverride: _promptTextCtrl.text.trim(),
    );
  }

  Future<void> _copyCaption() async {
    final text = _terminalTextCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No caption text to copy!')));
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VLM caption copied to clipboard!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _crunch,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_vlmCtrl.isStreaming) {
            _vlmCtrl.abort();
          }
        },
      },
      child: Focus(
        autofocus: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: _buildImagePane()),
                  Container(width: 2, color: AppTheme.xCopySteelDark),
                  Expanded(flex: 6, child: _buildConsolePane()),
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 4, child: _buildImagePane()),
                  Container(height: 2, color: AppTheme.xCopySteelDark),
                  Expanded(flex: 6, child: _buildConsolePane()),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildImagePane() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(8),
      child: RetroPanel(
        style: RetroPanelStyle.sunkenCrt,
        backgroundColor: Colors.transparent,
        child: ClipRect(
          child: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.1,
            maxScale: 10.0,
            child: Center(
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    'FAILED TO LOAD IMAGE:\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: AppTheme.xCopyRed,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConsolePane() {
    final vlm = _vlmCtrl;
    final state = vlm.state;

    final ledColor = switch (state) {
      PipelineProcessing() => AppTheme.xCopyAmber,
      PipelineError() => AppTheme.xCopyRed,
      PipelineReady() => AppTheme.xCopyGreen,
      PipelineIdle() => AppTheme.xCopyCyan,
    };

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Console Header Deck
          Row(
            children: [
              RetroLed(isActive: true, activeColor: ledColor, size: 8),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'VLM // VISION ANALYSIS',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppTheme.xCopyCyan,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.xCopySteel.withValues(alpha: 0.4),
                  border: Border.all(
                    color: AppTheme.xCopySteelLight,
                    width: 1.0,
                  ),
                ),
                child: Text(
                  vlm.config.model.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.xCopyAmber,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              RetroButton(
                label: 'COPY',
                fontSize: 10,
                onPressed:
                    (_terminalTextCtrl.text.isNotEmpty ||
                        vlm.accumulatedText.isNotEmpty)
                    ? _copyCaption
                    : null,
              ),
              const SizedBox(width: 6),
              RetroButton(
                label: 'CFG',
                fontSize: 10,
                textColor: AppTheme.xCopyCyan,
                onPressed: () => VlmSettingsDialog.show(context, vlm),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // CRT Terminal Output Area
          Expanded(
            child: RetroPanel(
              style: RetroPanelStyle.sunkenCrt,
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.all(12),
              child: _buildTerminalBody(),
            ),
          ),
          const SizedBox(height: 8),

          // Bottom Prompt Deck & Execution
          _buildPromptDeck(),
        ],
      ),
    );
  }

  Widget _buildTerminalBody() {
    final vlm = _vlmCtrl;
    final state = vlm.state;

    if (state is PipelineError) {
      final errorState = state as PipelineError<String>;
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '[ ! ]',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.xCopyRed,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'VLM INFERENCE FAILURE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.xCopyRed,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  errorState.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppTheme.xCopyAmber,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RetroButton(
                label: 'OPEN CONFIG',
                textColor: AppTheme.xCopyCyan,
                onPressed: () => VlmSettingsDialog.show(context, vlm),
              ),
            ],
          ),
        ),
      );
    }

    if (_terminalTextCtrl.text.isEmpty &&
        vlm.accumulatedText.isEmpty &&
        state is PipelineIdle) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RetroLed(
              isActive: true,
              activeColor: AppTheme.xCopyCyan,
              size: 10,
            ),
            const SizedBox(height: 12),
            const Text(
              'NEURAL VISION READY',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
                color: AppTheme.xCopyGreen,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'TARGET: ${vlm.config.endpoint}\nMODEL: ${vlm.config.model}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: AppTheme.xCopyGreen.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'SELECT PRESET BELOW AND PRESS [CRUNCH] OR (CTRL+ENTER)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: AppTheme.xCopyAmber,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      );
    }

    return TextField(
      controller: _terminalTextCtrl,
      focusNode: _terminalFocusNode,
      scrollController: _terminalScrollCtrl,
      maxLines: null,
      expands: true,
      readOnly: vlm.isStreaming,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: AppTheme.xCopyGreen,
        height: 1.4,
        letterSpacing: 0.5,
      ),
      cursorColor: AppTheme.xCopyAmber,
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildPromptDeck() {
    final vlm = _vlmCtrl;
    final activePreset = vlm.config.activePreset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Preset Pills & MRU selector row
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RetroButton(
              label: 'DESC',
              fontSize: 10,
              isSelected: activePreset == VlmPromptPreset.description,
              onPressed: () => _selectPreset(VlmPromptPreset.description),
            ),
            RetroButton(
              label: 'TAGS',
              fontSize: 10,
              isSelected: activePreset == VlmPromptPreset.visualTags,
              onPressed: () => _selectPreset(VlmPromptPreset.visualTags),
            ),
            RetroButton(
              label: 'BOORU',
              fontSize: 10,
              isSelected: activePreset == VlmPromptPreset.booruTags,
              onPressed: () => _selectPreset(VlmPromptPreset.booruTags),
            ),
            // 5-item MRU history popup
            PopupMenuButton<String>(
              tooltip: 'Recent Custom Prompts',
              color: AppTheme.xCopySteelDark,
              shape: Border.all(color: AppTheme.xCopyCyan, width: 1.0),
              onSelected: _selectMruPrompt,
              itemBuilder: (context) {
                final history = vlm.config.promptHistory;
                if (history.isEmpty) {
                  return const [
                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        'NO RECENT PROMPTS',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppTheme.xCopySteelLight,
                        ),
                      ),
                    ),
                  ];
                }
                return history.map((prompt) {
                  final display = prompt.length > 36
                      ? '${prompt.substring(0, 36)}...'
                      : prompt;
                  return PopupMenuItem<String>(
                    value: prompt,
                    child: Text(
                      display,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.xCopyGreen,
                      ),
                    ),
                  );
                }).toList();
              },
              child: const RetroButton(
                label: 'MRU ▼',
                fontSize: 10,
                textColor: AppTheme.xCopyCyan,
                onPressed: null, // PopupMenuButton handles tap
              ),
            ),
            if (vlm.tokenCount > 0)
              Text(
                '${vlm.tokenCount} TOKENS (${(vlm.elapsedTime.inMilliseconds / 1000).toStringAsFixed(1)}s)',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: AppTheme.xCopyAmber,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // Custom Prompt input area
        Container(
          decoration: BoxDecoration(
            color: AppTheme.xCopyCrtBlack.withValues(alpha: 0.35),
            border: Border.all(
              color: AppTheme.xCopyCyan.withValues(alpha: 0.6),
              width: 1.0,
            ),
          ),
          child: TextField(
            controller: _promptTextCtrl,
            focusNode: _promptFocusNode,
            maxLines: 6,
            minLines: 3,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppTheme.xCopyGreen,
              letterSpacing: 0.5,
              height: 1.35,
            ),
            cursorColor: AppTheme.xCopyGreen,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: InputBorder.none,
              hintText: 'Enter system prompt or neural vision instructions...',
              hintStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppTheme.xCopySteelLight.withValues(alpha: 0.6),
              ),
            ),
            onChanged: (text) {
              vlm.setCustomPrompt(text);
            },
          ),
        ),
        const SizedBox(height: 8),

        // Execution buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TIP: CTRL+ENTER TO CRUNCH',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9.5,
                color: AppTheme.xCopySteelLight,
              ),
            ),
            if (vlm.isStreaming)
              RetroButton(
                label: 'ABORT STREAM',
                shortcut: 'ESC',
                textColor: AppTheme.xCopyRed,
                onPressed: () => vlm.abort(),
              )
            else
              RetroButton(
                label: 'CRUNCH NEURAL VLM',
                shortcut: 'CTRL+ENTER',
                textColor: AppTheme.xCopyGreen,
                onPressed: _crunch,
              ),
          ],
        ),
      ],
    );
  }
}
