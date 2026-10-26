import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/retro_button.dart';
import '../widgets/retro_led.dart';
import '../widgets/retro_panel.dart';
import '../widgets/retro_resize_dialog.dart';

/// Helper class encapsulating styled modal dialogs for IMGCRUNCH.
class RetroDialogHelper {
  RetroDialogHelper._();

  /// Shows the retro command reference and keyboard shortcut table dialog.
  static Future<void> showHelpDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: RetroPanel(
            style: RetroPanelStyle.rivetedPlate,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const RetroLed(
                      isActive: true,
                      activeColor: AppTheme.xCopyAmber,
                      size: 8,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'IMGCRUNCH // COMMAND REFERENCE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                        color: ctx.wireframeCyan,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: ctx.wireframeCyanDim,
                        size: 18,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: ctx.wireframeCyanDim.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: IntrinsicColumnWidth(),
                        1: FlexColumnWidth(),
                      },
                      children: const [
                        TableRow(
                          children: [
                            _HelpKey('1 / 2 / 3 / 4 / 5'),
                            _HelpDesc(
                              'Normal / ELA / ASCII / Strings / VLM Mode',
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('SPACE / →'),
                            _HelpDesc('Next image in playlist'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('BACKSPACE / ←'),
                            _HelpDesc('Previous image in playlist'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('R'),
                            _HelpDesc('Resize Image (Lanczos3 Dialog)'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('0 (ZERO)'),
                            _HelpDesc(
                              'Toggle Fit to window / 100% Actual Scale',
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('CTRL + SCROLL'),
                            _HelpDesc('Focal-point Zoom (0.02x - 50x)'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('DOUBLE CLICK'),
                            _HelpDesc('Toggle 100% Actual Scale'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('MIDDLE CLICK'),
                            _HelpDesc('Reset Viewport Zoom & Pan'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('P'),
                            _HelpDesc(
                              'Toggle Pixel Eyedropper & Loupe (Click copies #HEX)',
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('O / CTRL+O'),
                            _HelpDesc('Open Single Image File'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('SHIFT + O'),
                            _HelpDesc('Open Directory / Playlist Folder'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('ALT + O'),
                            _HelpDesc('Open Specific Path (Direct Entry)'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('CTRL + C'),
                            _HelpDesc(
                              'Contextual Copy (Image / ELA / ASCII / Strings)',
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('CTRL + V'),
                            _HelpDesc('Paste Image from System Clipboard'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('M'),
                            _HelpDesc('Open Retro Bottom Menu Console'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('H / F1'),
                            _HelpDesc('Open Command Reference (Help)'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('S / SHIFT+S'),
                            _HelpDesc(
                              'Cycle Sort (Name/Date/Size) / Toggle Direction',
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('F5'),
                            _HelpDesc('Refresh Directory Playlist'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('ESC'),
                            _HelpDesc('Close Dialog / Exit Station'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: RetroButton(
                    label: 'CLOSE',
                    shortcut: 'ESC',
                    textColor: AppTheme.xCopyAmber,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a manual path entry dialog to open a specific file or directory.
  static Future<void> showOpenPathDialog(
    BuildContext context, {
    required ValueChanged<String> onPathSubmitted,
  }) {
    final textController = TextEditingController();
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('OPEN FILE OR DIRECTORY'),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: AppTheme.xCopyGreen,
            fontSize: 13,
          ),
          decoration: const InputDecoration(
            hintText: '/path/to/image.png or /path/to/folder',
            labelText: 'TARGET PATH',
            hintStyle: TextStyle(color: AppTheme.xCopyCyanDim),
            labelStyle: TextStyle(color: AppTheme.xCopyCyan),
          ),
          onSubmitted: (val) {
            Navigator.of(ctx).pop();
            if (val.trim().isNotEmpty) {
              onPathSubmitted(val.trim());
            }
          },
        ),
        actions: [
          RetroButton(
            label: 'CANCEL',
            textColor: AppTheme.xCopyRed,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          RetroButton(
            label: 'OPEN',
            textColor: AppTheme.xCopyAmber,
            onPressed: () {
              Navigator.of(ctx).pop();
              if (textController.text.trim().isNotEmpty) {
                onPathSubmitted(textController.text.trim());
              }
            },
          ),
        ],
      ),
    );
  }

  /// Shows the interactive retro resize dialog.
  static Future<void> showResizeDialog(
    BuildContext context, {
    required String imagePath,
    required Size naturalSize,
    required ValueChanged<String> onSaved,
    ValueChanged<bool>? onProcessingChanged,
  }) {
    return RetroResizeDialog.show(
      context,
      imagePath: imagePath,
      naturalSize: naturalSize,
      onSaved: onSaved,
      onProcessingChanged: onProcessingChanged,
    );
  }
}

class _HelpKey extends StatelessWidget {
  final String text;
  const _HelpKey(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.xCopyAmber,
          letterSpacing: 0.8,
          fontFeatures: [FontFeature.slashedZero()],
        ),
      ),
    );
  }
}

class _HelpDesc extends StatelessWidget {
  final String text;
  const _HelpDesc(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: Colors.white70,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
