import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                            _HelpKey('← / SPACE'),
                            _HelpDesc('Next image in playlist'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('→ / BACKSPACE'),
                            _HelpDesc('Previous image in playlist'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('HOME / END'),
                            _HelpDesc('Jump to First / Last specimen'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _HelpKey('DEL'),
                            _HelpDesc('Delete specimen (Confirmation Dialog)'),
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

  /// Shows a retro confirmation dialog for permanently deleting a specimen.
  /// Returns `true` if deletion was confirmed, or `false`/`null` if cancelled.
  static Future<bool?> showDeleteConfirmationDialog(
    BuildContext context, {
    required String fileName,
    required String filePath,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            Navigator.of(ctx).pop(false);
          },
          const SingleActivator(LogicalKeyboardKey.delete): () {
            Navigator.of(ctx).pop(true);
          },
          const SingleActivator(LogicalKeyboardKey.enter): () {
            Navigator.of(ctx).pop(true);
          },
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
            Navigator.of(ctx).pop(true);
          },
        },
        child: Focus(
          autofocus: true,
          child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
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
                        activeColor: AppTheme.xCopyRed,
                        size: 8,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'IMGCRUNCH // CONFIRM FILE DELETION',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: AppTheme.xCopyRed,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: ctx.wireframeCyanDim,
                          size: 18,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 1,
                    color: AppTheme.xCopyRed.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'PERMANENTLY DELETE SPECIMEN FROM DISK?',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.xCopyCrtBlack,
                      border: Border.all(
                        color: AppTheme.xCopyRed.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FILE: $fileName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.xCopyAmber,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          filePath,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: ctx.wireframeCyanDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'WARNING: THIS ACTION CANNOT BE UNDONE.',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.xCopyRed,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      RetroButton(
                        label: 'CANCEL',
                        shortcut: 'ESC',
                        textColor: AppTheme.xCopyCyan,
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                      const SizedBox(width: 12),
                      RetroButton(
                        label: 'DELETE',
                        shortcut: 'DEL',
                        textColor: AppTheme.xCopyRed,
                        isSelected: true,
                        onPressed: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
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
