import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/image_controller.dart';
import '../src/rust/api/ela.dart';
import '../theme/app_theme.dart';
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
      final fileBytes = await File(path).readAsBytes();
      final result = await processElaBytes(rawBytes: fileBytes, scale: 25);
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
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Open Path (O)'),
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

    return InteractiveViewer(
      transformationController: _transformController,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.05,
      maxScale: 35.0,
      child: Center(child: content),
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
        const SingleActivator(LogicalKeyboardKey.keyO): _showOpenPathDialog,
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Scaffold(
          backgroundColor: context.backgroundLayer,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Main edge-to-edge canvas
              _buildImageCanvas(),

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
    );
  }
}
