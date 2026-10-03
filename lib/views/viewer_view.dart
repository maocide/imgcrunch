import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/image_controller.dart';
import '../services/rust_image_service.dart';
import '../theme/app_theme.dart';
import '../utils/clipboard_helper.dart';
import '../utils/file_dialog_helper.dart';
import '../widgets/proximity_fab.dart';

enum ViewMode { normal, ela, ascii }

class ViewerView extends StatefulWidget {
  final ImageController controller;

  const ViewerView({super.key, required this.controller});

  @override
  State<ViewerView> createState() => _ViewerViewState();
}

class _ViewerViewState extends State<ViewerView> {
  final TransformationController _transformController =
      TransformationController();
  final FocusNode _focusNode = FocusNode();
  ViewMode _activeMode = ViewMode.normal;
  double _currentScale = 1.0;
  Uint8List? _elaBytes;
  bool _isProcessingEla = false;
  String? _elaError;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onImageChange);
    _transformController.addListener(_onTransformChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onImageChange);
    _transformController.removeListener(_onTransformChange);
    _transformController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onImageChange() {
    _resetTransform();
    _elaBytes = null;
    _elaError = null;
    setState(() {});
    if (_activeMode == ViewMode.ela) {
      _generateEla();
    }
  }

  Future<void> _generateEla() async {
    final path = widget.controller.currentPath;
    if (path == null) return;
    setState(() {
      _isProcessingEla = true;
      _elaError = null;
    });
    try {
      final result = await RustImageService.instance.generateElaFromFile(
        path,
        scale: 25,
      );
      if (mounted) {
        setState(() {
          _elaBytes = result;
          _isProcessingEla = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _elaError = e.toString();
          _isProcessingEla = false;
        });
      }
    }
  }

  void _onTransformChange() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.01) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _resetTransform() {
    _transformController.value = Matrix4.identity();
    setState(() {
      _currentScale = 1.0;
    });
  }

  void _zoomAt(Offset focalPoint, double scaleFactor) {
    final matrix = _transformController.value.clone();
    final currentScale = matrix.getMaxScaleOnAxis();
    final newScale = currentScale * scaleFactor;
    if (newScale < 0.05 || newScale > 35.0) return;

    final t1 = Matrix4.translationValues(focalPoint.dx, focalPoint.dy, 0.0);
    final s = Matrix4.diagonal3Values(scaleFactor, scaleFactor, 1.0);
    final t2 = Matrix4.translationValues(-focalPoint.dx, -focalPoint.dy, 0.0);
    _transformController.value = t1 * s * t2 * matrix;
  }

  Future<void> _copyImageToClipboard() async {
    final path = widget.controller.currentPath;
    if (path == null) return;
    try {
      final Uint8List bytes;
      if (_activeMode == ViewMode.ela && _elaBytes != null) {
        bytes = _elaBytes!;
      } else {
        bytes = await File(path).readAsBytes();
      }

      final success = await ClipboardHelper.copyImageBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Image copied to clipboard! (PNG)'
                : 'Failed to copy to clipboard',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to copy image: $e')),
      );
    }
  }

  Future<void> _pasteImageFromClipboard() async {
    try {
      final images = await ClipboardHelper.getImagesFromClipboard();
      if (!mounted) return;
      if (images.isNotEmpty) {
        widget.controller.loadPath(images.first);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image found in clipboard')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error pasting from clipboard: $e')),
      );
    }
  }

  Future<void> _pickImageFile() async {
    final path = await FileDialogHelper.pickImage();
    if (path != null && mounted) {
      widget.controller.loadPath(path);
    }
  }

  Future<void> _pickDirectory() async {
    final path = await FileDialogHelper.pickDirectory();
    if (path != null && mounted) {
      widget.controller.loadPath(path);
    }
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildMenuSheet(ctx),
    );
  }

  void _showOpenPathDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Image or Folder'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '/path/to/image.png or /path/to/folder',
            labelText: 'File or Directory Path',
          ),
          onSubmitted: (val) {
            Navigator.of(ctx).pop();
            if (val.trim().isNotEmpty) {
              widget.controller.loadPath(val.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (textController.text.trim().isNotEmpty) {
                widget.controller.loadPath(textController.text.trim());
              }
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSheet(BuildContext ctx) {
    final c = widget.controller;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: ctx.overlayLayerPop,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ctx.borderSubtle),
        boxShadow: AppTheme.floatingShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'imgcrunch controls',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ctx.colors.secondary,
                ),
              ),
              if (c.hasImages)
                Text(
                  '${c.currentIndex + 1} / ${c.playlist.length}',
                  style: TextStyle(
                    color: ctx.textSubdued,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (c.currentFileName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              c.currentFileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: ctx.textMuted),
            ),
          ],
          const SizedBox(height: 16),
          // View Mode Selector
          Row(
            children: [
              _modeChip(ViewMode.normal, 'Normal (1)'),
              const SizedBox(width: 8),
              _modeChip(ViewMode.ela, 'ELA (2) [Forensics]'),
              const SizedBox(width: 8),
              _modeChip(ViewMode.ascii, 'ASCII (3)'),
            ],
          ),
          const SizedBox(height: 20),
          // Actions
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.image_outlined),
                label: const Text('Open Image (O)'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _pickImageFile();
                },
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Open Folder'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _pickDirectory();
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_road_rounded),
                label: const Text('Manual Path...'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showOpenPathDialog();
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reset Zoom (0)'),
                onPressed: () {
                  _resetTransform();
                  Navigator.of(ctx).pop();
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy (Ctrl+C)'),
                onPressed: c.hasImages
                    ? () {
                        Navigator.of(ctx).pop();
                        _copyImageToClipboard();
                      }
                    : null,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.paste_rounded),
                label: const Text('Paste (Ctrl+V)'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _pasteImageFromClipboard();
                },
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Previous Image (Left)',
                onPressed: c.hasImages ? c.previous : null,
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.arrow_forward_rounded),
                tooltip: 'Next Image (Right)',
                onPressed: c.hasImages ? c.next : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeChip(ViewMode mode, String label) {
    final isSelected = _activeMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: context.colors.secondary.withValues(alpha: 0.3),
      onSelected: (_) {
        setState(() => _activeMode = mode);
        Navigator.of(context).pop();
        if (mode == ViewMode.ela && _elaBytes == null) {
          _generateEla();
        }
      },
    );
  }

  Widget _buildImageCanvas() {
    final path = widget.controller.currentPath;
    if (path == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_search_rounded,
              size: 64,
              color: context.colors.secondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No image loaded',
              style: TextStyle(
                fontSize: 18,
                color: context.textBody,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Press "O" or click the corner button to open a file or directory',
              style: TextStyle(fontSize: 13, color: context.textSubdued),
            ),
          ],
        ),
      );
    }

    Widget content = Image.file(
      File(path),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) => Center(
        child: Text(
          'Failed to load image:\n$error',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.error),
        ),
      ),
    );

    if (_activeMode == ViewMode.ela) {
      if (_isProcessingEla) {
        content = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: context.colors.secondary),
              const SizedBox(height: 16),
              Text(
                'Crunching ELA in Rust...',
                style: TextStyle(
                  color: context.colors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      } else if (_elaError != null) {
        content = Center(
          child: Text(
            'ELA Error:\n$_elaError',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.error),
          ),
        );
      } else if (_elaBytes != null) {
        content = Image.memory(
          _elaBytes!,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        );
      }
    }
 else if (_activeMode == ViewMode.ascii) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.greenAccent,
              BlendMode.color,
            ),
            child: content,
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ASCII MODE (Pending shader / renderer)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final interactive = InteractiveViewer(
      transformationController: _transformController,
      boundaryMargin: const EdgeInsets.all(0.0),
      minScale: 0.05,
      maxScale: 35.0,
      scaleEnabled: false,
      panEnabled: true,
      child: Center(child: content),
    );

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final isCtrl = HardwareKeyboard.instance.isControlPressed;
          if (isCtrl) {
            final factor = event.scrollDelta.dy < 0 ? 1.15 : 0.87;
            _zoomAt(event.localPosition, factor);
          } else {
            if (event.scrollDelta.dy > 0) {
              widget.controller.next();
            } else if (event.scrollDelta.dy < 0) {
              widget.controller.previous();
            }
          }
        }
      },
      onPointerDown: (event) {
        if (event.buttons == kMiddleMouseButton) {
          _resetTransform();
        }
      },
      child: GestureDetector(onDoubleTap: _resetTransform, child: interactive),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => c.next(),
        const SingleActivator(LogicalKeyboardKey.space): () => c.next(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => c.previous(),
        const SingleActivator(LogicalKeyboardKey.backspace): () => c.previous(),
        const SingleActivator(LogicalKeyboardKey.digit0): _resetTransform,
        const SingleActivator(LogicalKeyboardKey.keyR): _resetTransform,
        const SingleActivator(LogicalKeyboardKey.digit1): () =>
            setState(() => _activeMode = ViewMode.normal),
        const SingleActivator(LogicalKeyboardKey.digit2): () {
          setState(() => _activeMode = ViewMode.ela);
          if (_elaBytes == null) _generateEla();
        },
        const SingleActivator(LogicalKeyboardKey.digit3): () =>
            setState(() => _activeMode = ViewMode.ascii),
        const SingleActivator(LogicalKeyboardKey.keyO): _pickImageFile,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _pickImageFile,
        const SingleActivator(LogicalKeyboardKey.keyO, alt: true):
            _showOpenPathDialog,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true):
            _copyImageToClipboard,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            _pasteImageFromClipboard,
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: DropTarget(
          onDragEntered: (_) => setState(() => _isDragging = true),
          onDragExited: (_) => setState(() => _isDragging = false),
          onDragDone: (detail) {
            setState(() => _isDragging = false);
            if (detail.files.isNotEmpty) {
              widget.controller.loadPath(detail.files.first.path);
            }
          },
          child: Scaffold(
            backgroundColor: context.backgroundLayer,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // Main edge-to-edge canvas
                _buildImageCanvas(),

                // Drag and drop overlay
                if (_isDragging)
                  Container(
                    color: context.backgroundLayer.withValues(alpha: 0.85),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: context.overlayLayerPop,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.colors.secondary,
                            width: 2,
                          ),
                          boxShadow: AppTheme.floatingShadow,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.file_download_rounded,
                              color: context.colors.secondary,
                              size: 36,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'DROP IMAGE TO LOAD',
                              style: TextStyle(
                                color: context.colors.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

              // Subtle Minimalist HUD (Status Pill)
              if (c.hasImages)
                Positioned(
                  top: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.backgroundLayer.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.currentFileName,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textBody,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(_currentScale * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // The invisible/proximity FAB
              ProximityFab(onPressed: _showMenu),
            ],
          ),
        ),
      ),
    ),
  );
}
}
