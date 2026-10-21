import 'package:flutter/material.dart';
import '../controllers/crunch_state_controller.dart';
import '../controllers/image_controller.dart';
import '../theme/app_theme.dart';
import 'retro_button.dart';
import 'retro_led.dart';
import 'retro_panel.dart';

/// Modal bottom sheet command deck for IMGCRUNCH with mode selector,
/// file operations, navigation, and retro quick actions.
class RetroCommandDeck extends StatelessWidget {
  final ImageController controller;
  final CrunchStateController crunchController;
  final VoidCallback onPickImage;
  final VoidCallback onPickDirectory;
  final VoidCallback onOpenPath;
  final VoidCallback onResetZoom;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onShowHelp;
  final VoidCallback onQuit;
  final VoidCallback? onToggleEyedropper;
  final bool isEyedropperActive;

  const RetroCommandDeck({
    super.key,
    required this.controller,
    required this.crunchController,
    required this.onPickImage,
    required this.onPickDirectory,
    required this.onOpenPath,
    required this.onResetZoom,
    required this.onCopy,
    required this.onPaste,
    required this.onShowHelp,
    required this.onQuit,
    this.onToggleEyedropper,
    this.isEyedropperActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return RetroPanel(
      style: RetroPanelStyle.rivetedPlate,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RetroLed(
                    isActive: true,
                    activeColor: AppTheme.xCopyGreen,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'IMGCRUNCH // COMMAND DECK',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AppTheme.xCopyCyan,
                    ),
                  ),
                ],
              ),
              if (c.hasImages)
                Text(
                  'TRACK: ${c.currentIndex + 1}/${c.playlist.length}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppTheme.xCopyAmber,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
            ],
          ),
          if (c.currentFileName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '> ${c.currentFileName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppTheme.xCopyGreen,
                letterSpacing: 0.8,
              ),
            ),
          ],
          const SizedBox(height: 14),
          // View Mode Selector
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RetroButton(
                label: 'NORMAL',
                shortcut: '1',
                textColor: AppTheme.xCopyCyan,
                isSelected: crunchController.activeMode == ViewMode.normal,
                onPressed: () {
                  crunchController.setMode(ViewMode.normal);
                  Navigator.of(context).pop();
                },
              ),
              RetroButton(
                label: 'ELA FORENSICS',
                shortcut: '2',
                textColor: AppTheme.xCopyAmber,
                isSelected: crunchController.activeMode == ViewMode.ela,
                onPressed: () {
                  crunchController.setMode(ViewMode.ela);
                  Navigator.of(context).pop();
                },
              ),
              RetroButton(
                label: 'ASCII MATRIX',
                shortcut: '3',
                textColor: AppTheme.xCopyGreen,
                isSelected: crunchController.activeMode == ViewMode.ascii,
                onPressed: () {
                  crunchController.setMode(ViewMode.ascii);
                  Navigator.of(context).pop();
                },
              ),
              RetroButton(
                label: 'STRINGS',
                shortcut: '4',
                textColor: AppTheme.xCopyAmber,
                isSelected: crunchController.activeMode == ViewMode.strings,
                onPressed: () {
                  crunchController.setMode(ViewMode.strings);
                  Navigator.of(context).pop();
                },
              ),
              RetroButton(
                label: 'VLM VISION',
                shortcut: '5',
                textColor: AppTheme.xCopyGreen,
                isSelected: crunchController.activeMode == ViewMode.vlm,
                onPressed: () {
                  crunchController.setMode(ViewMode.vlm);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RetroButton(
                icon: Icons.image_outlined,
                label: 'OPEN IMAGE',
                shortcut: 'O',
                textColor: AppTheme.xCopyAmber,
                onPressed: () {
                  Navigator.of(context).pop();
                  onPickImage();
                },
              ),
              RetroButton(
                icon: Icons.folder_open_rounded,
                label: 'OPEN FOLDER',
                textColor: AppTheme.xCopyAmber,
                onPressed: () {
                  Navigator.of(context).pop();
                  onPickDirectory();
                },
              ),
              RetroButton(
                icon: Icons.edit_road_rounded,
                label: 'MANUAL PATH',
                textColor: AppTheme.xCopyCyan,
                onPressed: () {
                  Navigator.of(context).pop();
                  onOpenPath();
                },
              ),
              RetroButton(
                icon: Icons.refresh_rounded,
                label: 'RESET ZOOM',
                shortcut: '0',
                textColor: AppTheme.xCopyCyan,
                onPressed: () {
                  onResetZoom();
                  Navigator.of(context).pop();
                },
              ),
              RetroButton(
                icon: Icons.colorize_rounded,
                label: 'PICKER',
                shortcut: 'P',
                textColor: AppTheme.xCopyCyan,
                isSelected: isEyedropperActive,
                onPressed: c.hasImages && onToggleEyedropper != null
                    ? () {
                        Navigator.of(context).pop();
                        onToggleEyedropper!();
                      }
                    : null,
              ),
              RetroButton(
                icon: Icons.copy_rounded,
                label: 'COPY',
                shortcut: 'Ctrl+C',
                textColor: AppTheme.xCopyGreen,
                onPressed: c.hasImages
                    ? () {
                        Navigator.of(context).pop();
                        onCopy();
                      }
                    : null,
              ),
              RetroButton(
                icon: Icons.paste_rounded,
                label: 'PASTE',
                shortcut: 'Ctrl+V',
                textColor: AppTheme.xCopyGreen,
                onPressed: () {
                  Navigator.of(context).pop();
                  onPaste();
                },
              ),
              RetroButton(
                icon: Icons.arrow_back_rounded,
                label: 'PREV',
                shortcut: 'Left',
                textColor: AppTheme.xCopyAmber,
                onPressed: c.hasImages ? c.previous : null,
              ),
              RetroButton(
                icon: Icons.arrow_forward_rounded,
                label: 'NEXT',
                shortcut: 'Right',
                textColor: AppTheme.xCopyAmber,
                onPressed: c.hasImages ? c.next : null,
              ),
              RetroButton(
                icon: Icons.help_outline_rounded,
                label: 'HELP',
                shortcut: 'H',
                textColor: AppTheme.xCopyCyan,
                onPressed: () {
                  Navigator.of(context).pop();
                  onShowHelp();
                },
              ),
              RetroButton(
                icon: Icons.power_settings_new_rounded,
                label: 'QUIT',
                shortcut: 'ESC',
                textColor: AppTheme.xCopyRed,
                onPressed: () {
                  Navigator.of(context).pop();
                  onQuit();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
