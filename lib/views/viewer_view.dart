import 'dart:io';
import 'dart:math';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/crunch_state_controller.dart';
import '../controllers/image_controller.dart';
import '../theme/app_theme.dart';
import '../utils/clipboard_helper.dart';
import '../utils/file_dialog_helper.dart';
import '../utils/image_matrix_helper.dart';
import '../widgets/proximity_fab.dart';
import '../widgets/retro_button.dart';
import '../widgets/retro_led.dart';
import '../widgets/retro_panel.dart';
import '../widgets/retro_status_bar.dart';

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
  late final CrunchStateController _crunchController = CrunchStateController(
    strMinLen: 6,
  );

  double _currentScale = 1.0;
  Size? _naturalSize;
  Size? _lastViewportSize;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onImageChange);
    _transformController.addListener(_onTransformChange);
    _crunchController.addListener(_onCrunchStateChange);
    _crunchController.onImageChanged(widget.controller.currentPath);
    _loadCurrentDimensions();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onImageChange);
    _transformController.removeListener(_onTransformChange);
    _transformController.dispose();
    _crunchController.removeListener(_onCrunchStateChange);
    _crunchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCrunchStateChange() {
    if (mounted) setState(() {});
  }

  void _loadCurrentDimensions() {
    final path = widget.controller.currentPath;
    if (path == null) return;
    ImageMatrixHelper.getImageDimensions(path).then((size) {
      if (!mounted || size == null || widget.controller.currentPath != path) {
        return;
      }
      setState(() {
        _naturalSize = size;
      });
      if (_lastViewportSize != null) {
        _resetTransform();
      }
    });
  }

  void _onImageChange() {
    _naturalSize = null;
    _crunchController.onImageChanged(widget.controller.currentPath);
    _loadCurrentDimensions();
  }

  void _onTransformChange() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.005) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _resetTransform({bool actualSize = false}) {
    if (_naturalSize != null && _lastViewportSize != null) {
      if (actualSize) {
        _transformController.value =
            ImageMatrixHelper.calculateActualSizeMatrix(
              imageSize: _naturalSize!,
              viewportSize: _lastViewportSize!,
            );
      } else {
        _transformController.value = ImageMatrixHelper.calculateFitMatrix(
          imageSize: _naturalSize!,
          viewportSize: _lastViewportSize!,
        );
      }
    } else {
      _transformController.value = Matrix4.identity();
    }
    setState(() {
      _currentScale = _transformController.value.getMaxScaleOnAxis();
    });
  }

  void _zoomAt(Offset focalPoint, double scaleFactor) {
    final nextMatrix = ImageMatrixHelper.zoomAt(
      currentMatrix: _transformController.value,
      focalPoint: focalPoint,
      scaleFactor: scaleFactor,
    );
    if (nextMatrix != null) {
      _transformController.value = nextMatrix;
    }
  }

  Future<void> _copyContent() async {
    final message = await _crunchController.copyActiveContent();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
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

  String _getStatusMessage(ImageController c) =>
      _crunchController.getStatusMessage(c.hasImages);

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
              widget.controller.loadPath(val.trim());
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
                widget.controller.loadPath(textController.text.trim());
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSheet(BuildContext ctx) {
    final c = widget.controller;
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
          Row(
            children: [
              RetroButton(
                label: 'NORMAL',
                shortcut: '1',
                textColor: AppTheme.xCopyCyan,
                isSelected: _crunchController.activeMode == ViewMode.normal,
                onPressed: () {
                  _crunchController.setMode(ViewMode.normal);
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(width: 8),
              RetroButton(
                label: 'ELA FORENSICS',
                shortcut: '2',
                textColor: AppTheme.xCopyAmber,
                isSelected: _crunchController.activeMode == ViewMode.ela,
                onPressed: () {
                  _crunchController.setMode(ViewMode.ela);
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(width: 8),
              RetroButton(
                label: 'ASCII MATRIX',
                shortcut: '3',
                textColor: AppTheme.xCopyGreen,
                isSelected: _crunchController.activeMode == ViewMode.ascii,
                onPressed: () {
                  _crunchController.setMode(ViewMode.ascii);
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(width: 8),
              RetroButton(
                label: 'STRINGS',
                shortcut: '4',
                textColor: AppTheme.xCopyAmber,
                isSelected: _crunchController.activeMode == ViewMode.strings,
                onPressed: () {
                  _crunchController.setMode(ViewMode.strings);
                  Navigator.of(ctx).pop();
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
                  Navigator.of(ctx).pop();
                  _pickImageFile();
                },
              ),
              RetroButton(
                icon: Icons.folder_open_rounded,
                label: 'OPEN FOLDER',
                textColor: AppTheme.xCopyAmber,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _pickDirectory();
                },
              ),
              RetroButton(
                icon: Icons.edit_road_rounded,
                label: 'MANUAL PATH',
                textColor: AppTheme.xCopyCyan,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showOpenPathDialog();
                },
              ),
              RetroButton(
                icon: Icons.refresh_rounded,
                label: 'RESET ZOOM',
                shortcut: '0',
                textColor: AppTheme.xCopyCyan,
                onPressed: () {
                  _resetTransform();
                  Navigator.of(ctx).pop();
                },
              ),
              RetroButton(
                icon: Icons.copy_rounded,
                label: 'COPY',
                shortcut: 'Ctrl+C',
                textColor: AppTheme.xCopyGreen,
                onPressed: c.hasImages
                    ? () {
                        Navigator.of(ctx).pop();
                        _copyContent();
                      }
                    : null,
              ),
              RetroButton(
                icon: Icons.paste_rounded,
                label: 'PASTE',
                shortcut: 'Ctrl+V',
                textColor: AppTheme.xCopyGreen,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _pasteImageFromClipboard();
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
            ],
          ),
        ],
      ),
    );
  }

  Color _modeColor(ViewMode mode) {
    switch (mode) {
      case ViewMode.normal:
        return AppTheme.xCopyCyan;
      case ViewMode.ela:
        return AppTheme.xCopyAmber;
      case ViewMode.ascii:
        return AppTheme.xCopyGreen;
      case ViewMode.strings:
        return AppTheme.xCopyAmber;
    }
  }

  Widget _buildStringsCanvas() {
    final path = widget.controller.currentPath;
    if (path == null) return const SizedBox.shrink();

    final state = _crunchController.stringsState;
    switch (state) {
      case PipelineProcessing(:final statusMessage):
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.xCopyAmber),
              const SizedBox(height: 16),
              Text(
                statusMessage,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: AppTheme.xCopyAmber,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        );

      case PipelineError(:final message):
        return Center(
          child: Text(
            'STRINGS ERROR:\n$message',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: AppTheme.xCopyRed,
            ),
          ),
        );

      case PipelineIdle():
        return const SizedBox.shrink();

      case PipelineReady(:final data):
        final rawStrings = data;
        final lines = rawStrings.trim().isEmpty
            ? <String>[]
            : rawStrings.trim().split('\n');

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 36),
          child: RetroPanel(
            style: RetroPanelStyle.sunkenCrt,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const RetroLed(
                      isActive: true,
                      activeColor: AppTheme.xCopyGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'FORENSIC STRINGS EXTRACTION (MIN_LEN: ${_crunchController.strMinLen}) // ${lines.length} ENTRIES',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.xCopyGreen,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    RetroButton(
                      icon: Icons.copy_rounded,
                      label: 'COPY ALL',
                      fontSize: 10,
                      textColor: AppTheme.xCopyAmber,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: rawStrings));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'All extracted strings copied to clipboard!',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: AppTheme.xCopyCyanDim, height: 1),
                const SizedBox(height: 8),
                Expanded(
                  child: lines.isEmpty
                      ? Center(
                          child: Text(
                            'NO PRINTABLE ASCII STRINGS >= ${_crunchController.strMinLen} CHARACTERS FOUND',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: AppTheme.xCopyCyanDim,
                            ),
                          ),
                        )
                      : Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            primary: true,
                            child: SelectableText(
                              rawStrings,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.35,
                                letterSpacing: 0.5,
                                color: AppTheme.xCopyGreen,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
    }
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
              color: AppTheme.xCopyCyanDim,
            ),
            const SizedBox(height: 16),
            const Text(
              'NO IMAGE LOADED',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                color: AppTheme.xCopyCyan,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'PRESS (O) OR CLICK MENU TO LOAD FILE/FOLDER',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppTheme.xCopyGreen,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    if (_crunchController.activeMode == ViewMode.strings) {
      return _buildStringsCanvas();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        if (_lastViewportSize != viewportSize) {
          final oldSize = _lastViewportSize;
          _lastViewportSize = viewportSize;
          if (_naturalSize != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (oldSize == null) {
                _resetTransform();
              } else {
                final wasFitted =
                    (ImageMatrixHelper.calculateFitMatrix(
                              imageSize: _naturalSize!,
                              viewportSize: oldSize,
                            ).getMaxScaleOnAxis() -
                            _currentScale)
                        .abs() <
                    0.05;
                if (wasFitted) {
                  _resetTransform(actualSize: false);
                }
              }
            });
          }
        }

        if (_naturalSize == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.xCopyCyan),
          );
        }

        Widget content;
        switch (_crunchController.activeMode) {
          case ViewMode.normal:
            content = SizedBox(
              width: _naturalSize!.width,
              height: _naturalSize!.height,
              child: Image.file(
                File(path),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    'Failed to load image:\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: AppTheme.xCopyRed,
                    ),
                  ),
                ),
              ),
            );

          case ViewMode.ela:
            content = SizedBox(
              width: _naturalSize!.width,
              height: _naturalSize!.height,
              child: switch (_crunchController.elaState) {
                PipelineProcessing(:final statusMessage) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: AppTheme.xCopyAmber,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        statusMessage,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: AppTheme.xCopyAmber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                PipelineError(:final message) => Center(
                  child: Text(
                    'ELA Error:\n$message',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: AppTheme.xCopyRed,
                    ),
                  ),
                ),
                PipelineReady<Uint8List>(:final data) => Image.memory(
                  data,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
                PipelineIdle() => const SizedBox.shrink(),
              },
            );

          case ViewMode.ascii:
            content = SizedBox(
              width: _naturalSize!.width,
              height: _naturalSize!.height,
              child: switch (_crunchController.asciiState) {
                PipelineProcessing(:final statusMessage) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.xCopyGreen),
                      SizedBox(height: 16),
                      Text(
                        statusMessage,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: AppTheme.xCopyGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                PipelineError(:final message) => Center(
                  child: Text(
                    'ASCII Error:\n$message',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: AppTheme.xCopyRed,
                    ),
                  ),
                ),
                PipelineReady<String>(:final data) => Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Text(
                      data,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        height: 0.9,
                        letterSpacing: 0.8,
                        color: AppTheme.xCopyGreen,
                      ),
                    ),
                  ),
                ),
                PipelineIdle() => const SizedBox.shrink(),
              },
            );

          case ViewMode.strings:
            content = const SizedBox.shrink();
        }

        final interactive = InteractiveViewer(
          transformationController: _transformController,
          boundaryMargin: EdgeInsets.all(
            max(viewportSize.width, viewportSize.height),
          ),
          minScale: 0.02,
          maxScale: 50.0,
          scaleEnabled: false,
          panEnabled: true,
          constrained: false,
          child: content,
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
          child: GestureDetector(
            onDoubleTap: () {
              final isCloseToActual = (_currentScale - 1.0).abs() < 0.05;
              _resetTransform(actualSize: !isCloseToActual);
            },
            child: interactive,
          ),
        );
      },
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
            _crunchController.setMode(ViewMode.normal),
        const SingleActivator(LogicalKeyboardKey.digit2): () =>
            _crunchController.setMode(ViewMode.ela),
        const SingleActivator(LogicalKeyboardKey.digit3): () =>
            _crunchController.setMode(ViewMode.ascii),
        const SingleActivator(LogicalKeyboardKey.digit4): () =>
            _crunchController.setMode(ViewMode.strings),
        const SingleActivator(LogicalKeyboardKey.keyM): _showMenu,
        const SingleActivator(LogicalKeyboardKey.keyO): _pickImageFile,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _pickImageFile,
        const SingleActivator(LogicalKeyboardKey.keyO, alt: true):
            _showOpenPathDialog,
        const SingleActivator(LogicalKeyboardKey.keyC, control: true):
            _copyContent,
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
                    color: Colors.black.withValues(alpha: 0.85),
                    child: Center(
                      child: RetroPanel(
                        style: RetroPanelStyle.rivetedPlate,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 20,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.file_download_rounded,
                              color: AppTheme.xCopyAmber,
                              size: 32,
                            ),
                            const SizedBox(width: 14),
                            const Text(
                              'DROP IMAGE TO CRUNCH',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: AppTheme.xCopyCyan,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Retro Instrument HUD Pill
                if (c.hasImages)
                  Positioned(
                    top: 14,
                    left: 14,
                    child: RetroPanel(
                      style: RetroPanelStyle.cyanWireframe,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RetroLed(
                            isActive: true,
                            size: 7,
                            activeColor: _modeColor(
                              _crunchController.activeMode,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _crunchController.activeMode.name.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: _modeColor(_crunchController.activeMode),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 1,
                            height: 12,
                            color: AppTheme.xCopyCyanDim,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            c.currentFileName,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 1,
                            height: 12,
                            color: AppTheme.xCopyCyanDim,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(_currentScale * 100).toInt()}%',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.xCopyAmber,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Permanent Bottom Retro Status Bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: RetroStatusBar(
                    statusText: _getStatusMessage(c),
                    zoomScale: _currentScale,
                    currentIndex: c.currentIndex,
                    totalCount: c.playlist.length,
                    trailing: RetroButton(
                      label: 'MENU',
                      shortcut: 'M',
                      fontSize: 9,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      onPressed: _showMenu,
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
