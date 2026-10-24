import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../retro_led.dart';
import 'retro_markdown_view.dart';

/// Lightweight retro collapsible drawer for displaying LLM/VLM cognitive reasoning
/// and thought process streams (<think>, reasoning_content, delta['reasoning']).
class RetroReasoningCollapsible extends StatelessWidget {
  const RetroReasoningCollapsible({
    super.key,
    required this.reasoning,
    required this.isExpanded,
    required this.onToggle,
    this.isStreaming = false,
  });

  final String reasoning;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    if (reasoning.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.xCopyCrtBlack.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isStreaming ? AppTheme.xCopyAmber : AppTheme.xCopySteelDark,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Toggle Bar
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 16,
                    color: AppTheme.xCopyAmber,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '🧠 COGNITIVE MATRIX // REASONING TRACE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppTheme.xCopyAmber,
                    ),
                  ),
                  const Spacer(),
                  if (isStreaming) ...[
                    const RetroLed(
                      isActive: true,
                      activeColor: AppTheme.xCopyAmber,
                      size: 6,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'THINKING',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.xCopyAmber,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ] else ...[
                    Text(
                      isExpanded ? '[COLLAPSE]' : '[EXPAND]',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: AppTheme.xCopySteelLight.withValues(alpha: 0.8),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Collapsible Markdown Body (only built when expanded)
          if (isExpanded)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.xCopySteelDark, width: 1.0),
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: SingleChildScrollView(
                child: RetroMarkdownView(data: reasoning),
              ),
            ),
        ],
      ),
    );
  }
}
