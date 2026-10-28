import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../controllers/crunch_state_controller.dart';
import '../controllers/image_controller.dart';
import '../models/operation_result.dart';
import '../services/config/app_config_manager.dart';
import '../services/pixel_reader.dart';
import '../theme/app_theme.dart';
import '../utils/clipboard_helper.dart';
import '../utils/file_dialog_helper.dart';
import '../utils/image_matrix_helper.dart';
import '../utils/retro_dialog_helper.dart';
import '../utils/window_title_helper.dart';
import '../widgets/amiga_copper_background.dart';
import '../widgets/retro_command_deck.dart';
import '../widgets/retro_button.dart';
import '../widgets/retro_led.dart';
import '../widgets/retro_floppy_disk.dart';
import '../widgets/retro_panel.dart';
import '../widgets/retro_pixel_loupe.dart';
import '../widgets/retro_status_bar.dart';
import 'vlm_view.dart';

class ViewerView extends StatefulWidget {
  final ImageController controller;
  final ViewMode? initialMode;
  final AppConfigManager? configManager;

  const ViewerView({
    super.key,
    required this.controller,
    this.initialMode,
    this.configManager,
  });

  @override
  State<ViewerView> createState() => _ViewerViewState();
}

class _ViewerViewState extends State<ViewerView> {
  final TransformationController _transformController =
      TransformationController();
  final FocusScopeNode _focusScopeNode = FocusScopeNode();
  late final CrunchStateController _crunchController = CrunchStateController(
    strMinLen: 6,
    configManager: widget.configManager,
  );

  double _currentScale = 1.0;
  Size? _naturalSize;
  Size? _lastViewportSize;
  bool _isDragging = false;
  bool _loadError = false;
  bool _isResizeProcessing = false;

  String? _transientStatusMessage;
  bool _isTransientError = false;
  Timer? _transientMessageTimer;

  bool _isEyedropperActive = false;
  PixelBuffer? _pixelBuffer;
  Point<int>? _hoveredPixel;
  Offset? _hoveredScreenPos;

  late final ViewerShortcutManager _shortcutManager;

  @override
  void initState() {
    super.initState();
    _shortcutManager = ViewerShortcutManager();
    if (widget.initialMode != null) {
      _crunchController.setMode(widget.initialMode!);
    }
    widget.controller.addListener(_onImageChange);
    _transformController.addListener(_onTransformChange);
    _crunchController.addListener(_onCrunchStateChange);
    _crunchController.onImageChanged(widget.controller.currentPath);
    _crunchController.vlmController.loadConfig();
    _loadCurrentDimensions();
  }

  @override
  void dispose() {
    _transientMessageTimer?.cancel();
    _shortcutManager.dispose();
    widget.controller.removeListener(_onImageChange);
    _transformController.removeListener(_onTransformChange);
    _transformController.dispose();
    _crunchController.removeListener(_onCrunchStateChange);
    _crunchController.dispose();
    _focusScopeNode.dispose();
    super.dispose();
  }

  void _setStatusMessage(
    String message, {
    bool isError = false,
    Duration timeout = const Duration(seconds: 4),
  }) {
    _transientMessageTimer?.cancel();
    setState(() {
      _transientStatusMessage = message;
      _isTransientError = isError;
    });
    _transientMessageTimer = Timer(timeout, () {
      if (mounted && _transientStatusMessage != null) {
        setState(() {
          _transientStatusMessage = null;
          _isTransientError = false;
        });
      }
    });
  }

  void _clearTransientStatus() {
    if (_transientStatusMessage != null) {
      _transientMessageTimer?.cancel();
      _transientStatusMessage = null;
      _isTransientError = false;
    }
  }

  void _handleResult(OperationResult result, {String? defaultSuccessMessage}) {
    if (result.isSuccess) {
      final msg = result.message ?? defaultSuccessMessage;
      if (msg != null && msg.isNotEmpty) {
        _setStatusMessage(msg, isError: false);
      }
    } else {
      _setStatusMessage(
        'ERR: ${result.error ?? "OPERATION FAILED"}',
        isError: true,
      );
    }
  }

  void _onCrunchStateChange() {
    if (!mounted) return;
    if (_isEyedropperActive &&
        (_crunchController.activeMode == ViewMode.strings ||
            _crunchController.activeMode == ViewMode.vlm)) {
      _isEyedropperActive = false;
      _hoveredPixel = null;
      _hoveredScreenPos = null;
      _pixelBuffer = null;
    }
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  void _loadCurrentDimensions() {
    final path = widget.controller.currentPath;
    if (path == null) return;
    ImageMatrixHelper.getImageDimensions(path).then((size) {
      if (!mounted || widget.controller.currentPath != path) {
        return;
      }
      setState(() {
        _naturalSize = size;
        _loadError = size == null;
      });
      if (_naturalSize != null && _lastViewportSize != null) {
        _resetTransform();
      }
    });
  }

  void _loadCurrentPixelBuffer() {
    final path = widget.controller.currentPath;
    if (path == null) {
      _pixelBuffer = null;
      return;
    }
    PixelBuffer.loadFromFile(path)
        .then((buffer) {
          if (!mounted || widget.controller.currentPath != path) {
            return;
          }
          setState(() {
            _pixelBuffer = buffer;
          });
        })
        .catchError((_) {
          if (mounted && widget.controller.currentPath == path) {
            setState(() {
              _pixelBuffer = null;
            });
          }
        });
  }

  void _onImageChange() {
    _clearTransientStatus();
    setState(() {
      _naturalSize = null;
      _loadError = false;
      _pixelBuffer = null;
      _hoveredPixel = null;
      _hoveredScreenPos = null;
    });
    _crunchController.onImageChanged(widget.controller.currentPath);
    _loadCurrentDimensions();
    if (_isEyedropperActive) {
      _loadCurrentPixelBuffer();
    }
  }

  void _toggleEyedropper() {
    if (!widget.controller.hasImages) return;
    if (_crunchController.activeMode == ViewMode.strings ||
        _crunchController.activeMode == ViewMode.vlm) {
      return;
    }
    setState(() {
      _isEyedropperActive = !_isEyedropperActive;
      if (!_isEyedropperActive) {
        _hoveredPixel = null;
        _hoveredScreenPos = null;
        _pixelBuffer = null;
      } else {
        _loadCurrentPixelBuffer();
      }
    });
  }

  Future<void> _handlePixelClick(Point<int> pixel) async {
    if (_pixelBuffer == null) return;
    final hex = _pixelBuffer!.getHex(pixel.x, pixel.y);
    await Clipboard.setData(ClipboardData(text: hex));
    if (!mounted) return;
    _setStatusMessage('PIXEL $hex COPIED (X:${pixel.x}, Y:${pixel.y})');
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

  void _toggleScale() {
    _clearTransientStatus();
    final isCloseToActual = (_currentScale - 1.0).abs() < 0.05;
    _resetTransform(actualSize: !isCloseToActual);
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
    final isErr =
        message.toLowerCase().contains('no ') ||
        message.toLowerCase().contains('error');
    _setStatusMessage(message, isError: isErr);
  }

  Future<void> _copyCurrentPath() async {
    final path = widget.controller.currentPath;
    if (path == null) {
      _handleResult(const OperationResult<void>.failure('NO SPECIMEN LOADED'));
      return;
    }
    await Clipboard.setData(ClipboardData(text: path));
    _handleResult(OperationResult<String>.success(path, 'PATH COPIED: $path'));
  }

  Future<void> _pasteImageFromClipboard() async {
    try {
      final images = await ClipboardHelper.getImagesFromClipboard();
      if (!mounted) return;
      if (images.isNotEmpty) {
        widget.controller.loadPath(images.first);
        _setStatusMessage('CLIPBOARD SPECIMEN IMPORTED');
      } else {
        _setStatusMessage('ERR: NO IMAGE IN CLIPBOARD', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _setStatusMessage('ERR: CLIPBOARD IMPORT FAILED ($e)', isError: true);
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
      builder: (ctx) => RetroCommandDeck(
        controller: widget.controller,
        crunchController: _crunchController,
        onPickImage: _pickImageFile,
        onPickDirectory: _pickDirectory,
        onOpenPath: _showOpenPathDialog,
        onResetZoom: _toggleScale,
        onCopy: _copyContent,
        onPaste: _pasteImageFromClipboard,
        onShowHelp: _showHelpDialog,
        onQuit: _handleEscape,
        onToggleEyedropper: _toggleEyedropper,
        isEyedropperActive: _isEyedropperActive,
      ),
    );
  }

  void _showOpenPathDialog() {
    RetroDialogHelper.showOpenPathDialog(
      context,
      onPathSubmitted: (path) {
        final f = File(path);
        final d = Directory(path);
        if (!f.existsSync() && !d.existsSync()) {
          _setStatusMessage('ERR: PATH NOT FOUND: $path', isError: true);
          return;
        }
        widget.controller.loadPath(path);
      },
    );
  }

  Widget _buildStringsCanvas() {
    final path = widget.controller.currentPath;
    if (path == null) return const SizedBox.shrink();

    final state = _crunchController.stringsState;
    switch (state) {
      case PipelineProcessing(:final statusMessage):
        return Center(
          child: RetroPanel(
            style: RetroPanelStyle.sunkenCrt,
            backgroundColor: AppTheme.xCopySteel.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RetroLed(
                  isActive: true,
                  activeColor: AppTheme.xCopyAmber,
                  size: 10,
                ),
                const SizedBox(height: 12),
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
            const RetroFloppyDisk(size: 110),
            const SizedBox(height: 20),
            const Text(
              'NO IMAGE LOADED',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                color: AppTheme.xCopyCyan,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'DF0: INSERT MEDIA // PRESS (O) OR DRAG & DROP',
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

    if (_crunchController.activeMode == ViewMode.vlm) {
      final path = widget.controller.currentPath;
      if (path != null) {
        return VlmView(
          imagePath: path,
          crunchController: _crunchController,
          naturalSize: _naturalSize,
        );
      }
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

        if (_loadError) {
          return SizedBox.expand(
            child: MouseRegion(
              cursor: _isEyedropperActive
                  ? SystemMouseCursors.precise
                  : MouseCursor.defer,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    final isCtrl = HardwareKeyboard.instance.isControlPressed;
                    if (isCtrl) {
                      final factor = event.scrollDelta.dy < 0 ? 1.15 : 0.87;
                      _zoomAt(event.localPosition, factor);
                    } else {
                      if (event.scrollDelta.dy > 0) {
                        _clearTransientStatus();
                        widget.controller.previous();
                      } else if (event.scrollDelta.dy < 0) {
                        _clearTransientStatus();
                        widget.controller.next();
                      }
                    }
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: _isEyedropperActive ? null : _toggleScale,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                          color: AppTheme.xCopyRed,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'CORRUPT OR UNSUPPORTED IMAGE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.xCopyRed,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: AppTheme.xCopyAmber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (_naturalSize == null) {
          return const SizedBox.shrink();
        }

        final filterQuality = _currentScale >= 1.0
            ? FilterQuality.none
            : FilterQuality.medium;

        Widget content;
        switch (_crunchController.activeMode) {
          case ViewMode.normal:
            content = SizedBox(
              width: _naturalSize!.width,
              height: _naturalSize!.height,
              child: Image.file(
                File(path),
                fit: BoxFit.fill,
                filterQuality: filterQuality,
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
            final elaState = _crunchController.elaState;
            Widget elaBody;
            if (elaState case PipelineReady<Uint8List>(:final data)) {
              elaBody = Image.memory(
                data,
                fit: BoxFit.fill,
                filterQuality: filterQuality,
              );
            } else if (elaState case PipelineError(:final message)) {
              elaBody = Center(
                child: Text(
                  'ELA Error:\n$message',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: AppTheme.xCopyRed,
                  ),
                ),
              );
            } else {
              // During PipelineProcessing or PipelineIdle: show base image without any matrix-deformed spinner!
              elaBody = Image.file(
                File(path),
                fit: BoxFit.fill,
                filterQuality: filterQuality,
              );
            }
            content = SizedBox(
              width: _naturalSize!.width,
              height: _naturalSize!.height,
              child: elaBody,
            );

          case ViewMode.ascii:
            final asciiState = _crunchController.asciiState;
            Widget asciiBody;
            if (asciiState case PipelineReady<AsciiCrunchResult>(:final data)) {
              asciiBody = Image.memory(
                data.imageBytes,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              );
            } else if (asciiState case PipelineError(:final message)) {
              asciiBody = Center(
                child: Text(
                  'ASCII Error:\n$message',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: AppTheme.xCopyRed,
                  ),
                ),
              );
            } else {
              // During PipelineProcessing or PipelineIdle: show base image without any matrix-deformed spinner!
              asciiBody = Image.file(
                File(path),
                fit: BoxFit.fill,
                filterQuality: filterQuality,
              );
            }
            content = SizedBox(
              width: _naturalSize!.width,
              height: _naturalSize!.height,
              child: asciiBody,
            );

          case ViewMode.strings:
          case ViewMode.vlm:
            content = const SizedBox.shrink();
        }

        final interactive = InteractiveViewer(
          transformationController: _transformController,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 0.02,
          maxScale: 50.0,
          scaleEnabled: false,
          panEnabled: !_isEyedropperActive,
          constrained: false,
          child: content,
        );

        return MouseRegion(
          cursor: _isEyedropperActive
              ? SystemMouseCursors.precise
              : MouseCursor.defer,
          onHover: (event) {
            if (_isEyedropperActive && _naturalSize != null) {
              final p = ImageMatrixHelper.viewportToImagePixel(
                transformMatrix: _transformController.value,
                viewportPosition: event.localPosition,
                imageSize: _naturalSize!,
              );
              if (p != _hoveredPixel ||
                  event.localPosition != _hoveredScreenPos) {
                setState(() {
                  _hoveredPixel = p;
                  _hoveredScreenPos = event.localPosition;
                });
              }
            }
          },
          onExit: (_) {
            if (_hoveredPixel != null || _hoveredScreenPos != null) {
              setState(() {
                _hoveredPixel = null;
                _hoveredScreenPos = null;
              });
            }
          },
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                final isCtrl = HardwareKeyboard.instance.isControlPressed;
                if (isCtrl) {
                  final factor = event.scrollDelta.dy < 0 ? 1.15 : 0.87;
                  _zoomAt(event.localPosition, factor);
                } else {
                  if (event.scrollDelta.dy > 0) {
                    _clearTransientStatus();
                    widget.controller.previous();
                  } else if (event.scrollDelta.dy < 0) {
                    _clearTransientStatus();
                    widget.controller.next();
                  }
                }
              }
            },
            onPointerDown: (event) {
              if (event.buttons == kMiddleMouseButton) {
                _resetTransform();
              } else if (_isEyedropperActive &&
                  event.buttons == kPrimaryMouseButton &&
                  _hoveredPixel != null) {
                _handlePixelClick(_hoveredPixel!);
              }
            },
            child: GestureDetector(
              onDoubleTap: _isEyedropperActive ? null : _toggleScale,
              child: interactive,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final isNormalLoading =
        _crunchController.activeMode == ViewMode.normal &&
        c.hasImages &&
        _naturalSize == null &&
        !_loadError;
    final isProcessing =
        isNormalLoading ||
        _isResizeProcessing ||
        (_crunchController.activeState is PipelineProcessing);

    final windowTitle = WindowTitleHelper.formatTitle(
      hasImages: c.hasImages,
      fileName: c.currentFileName,
      currentIndex: c.currentIndex,
      totalCount: c.playlist.length,
      scale: _currentScale,
    );

    WindowTitleHelper.updateTitle(
      hasImages: c.hasImages,
      fileName: c.currentFileName,
      currentIndex: c.currentIndex,
      totalCount: c.playlist.length,
      scale: _currentScale,
    );

    final shortcutBindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
      const SingleActivator(LogicalKeyboardKey.keyH): _showHelpDialog,
      const SingleActivator(LogicalKeyboardKey.f1): _showHelpDialog,
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
        _clearTransientStatus();
        c.next();
      },
      const SingleActivator(LogicalKeyboardKey.space): () {
        _clearTransientStatus();
        c.next();
      },
      const SingleActivator(LogicalKeyboardKey.arrowRight): () {
        _clearTransientStatus();
        c.previous();
      },
      const SingleActivator(LogicalKeyboardKey.backspace): () {
        _clearTransientStatus();
        c.previous();
      },
      const SingleActivator(LogicalKeyboardKey.home): () {
        _clearTransientStatus();
        c.first();
      },
      const SingleActivator(LogicalKeyboardKey.end): () {
        _clearTransientStatus();
        c.last();
      },
      const SingleActivator(LogicalKeyboardKey.delete):
          _confirmDeleteCurrentFile,
      const SingleActivator(LogicalKeyboardKey.digit0): _toggleScale,
      const SingleActivator(LogicalKeyboardKey.numpad0): _toggleScale,
      const SingleActivator(LogicalKeyboardKey.keyR): _showResizeDialog,
      const SingleActivator(LogicalKeyboardKey.digit1): () {
        _clearTransientStatus();
        _crunchController.setMode(ViewMode.normal);
      },
      const SingleActivator(LogicalKeyboardKey.digit2): () {
        _clearTransientStatus();
        _crunchController.setMode(ViewMode.ela);
      },
      const SingleActivator(LogicalKeyboardKey.digit3): () {
        _clearTransientStatus();
        _crunchController.setMode(ViewMode.ascii);
      },
      const SingleActivator(LogicalKeyboardKey.digit4): () {
        _clearTransientStatus();
        _crunchController.setMode(ViewMode.strings);
      },
      const SingleActivator(LogicalKeyboardKey.digit5): () {
        _clearTransientStatus();
        _crunchController.setMode(ViewMode.vlm);
      },
      const SingleActivator(LogicalKeyboardKey.keyP): _toggleEyedropper,
      const SingleActivator(LogicalKeyboardKey.keyM): _showMenu,
      const SingleActivator(LogicalKeyboardKey.keyO): _pickImageFile,
      const SingleActivator(LogicalKeyboardKey.keyO, control: true):
          _pickImageFile,
      const SingleActivator(LogicalKeyboardKey.keyO, shift: true):
          _pickDirectory,
      const SingleActivator(LogicalKeyboardKey.keyO, alt: true):
          _showOpenPathDialog,
      const SingleActivator(LogicalKeyboardKey.keyS): () {
        _clearTransientStatus();
        c.cycleSortCriterion();
      },
      const SingleActivator(LogicalKeyboardKey.keyS, shift: true): () {
        _clearTransientStatus();
        c.toggleSortDirection();
      },
      const SingleActivator(LogicalKeyboardKey.f5): () {
        _clearTransientStatus();
        c.refresh();
      },
      const SingleActivator(LogicalKeyboardKey.keyC): _copyCurrentPath,
      const SingleActivator(LogicalKeyboardKey.keyC, control: true):
          _copyContent,
      const SingleActivator(LogicalKeyboardKey.keyV, control: true):
          _pasteImageFromClipboard,
    };

    _shortcutManager.shortcuts = <ShortcutActivator, Intent>{
      for (final entry in shortcutBindings.entries)
        entry.key: _ViewerShortcutIntent(entry.value),
    };

    return Title(
      title: windowTitle,
      color: const Color(0xFF000000),
      child: Shortcuts.manager(
        manager: _shortcutManager,
        child: Actions(
          actions: <Type, Action<Intent>>{
            _ViewerShortcutIntent: CallbackAction<_ViewerShortcutIntent>(
              onInvoke: (_ViewerShortcutIntent intent) => intent.callback(),
            ),
          },
          child: FocusScope(
            node: _focusScopeNode,
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
              child: AmigaCopperBackground(
                isProcessing: isProcessing,
                mode: _crunchController.activeMode,
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Column(
                    children: [
                      // Canvas Viewport Area
                      Expanded(
                        child: Stack(
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
                                        Text(
                                          'DROP IMAGE TO CRUNCH',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            color: context.wireframeCyan,
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

                            // Pixel Eyedropper Loupe
                            if (_isEyedropperActive &&
                                _hoveredPixel != null &&
                                _pixelBuffer != null &&
                                _lastViewportSize != null)
                              RetroPixelLoupe(
                                pixelCoordinates: _hoveredPixel!,
                                color: _pixelBuffer!.getPixel(
                                  _hoveredPixel!.x,
                                  _hoveredPixel!.y,
                                ),
                                hexCode: _pixelBuffer!.getHex(
                                  _hoveredPixel!.x,
                                  _hoveredPixel!.y,
                                ),
                                rgbText: _pixelBuffer!.getRgb(
                                  _hoveredPixel!.x,
                                  _hoveredPixel!.y,
                                ),
                                patch: _pixelBuffer!.getPatch(
                                  _hoveredPixel!.x,
                                  _hoveredPixel!.y,
                                  radius: 4,
                                ),
                                screenPosition:
                                    _hoveredScreenPos ?? Offset.zero,
                                viewportSize: _lastViewportSize!,
                              ),
                          ],
                        ),
                      ),

                      // Permanent Bottom Retro Status Bar (solid console base)
                      Builder(
                        builder: (context) {
                          final isPipelineError =
                              _crunchController.activeState is PipelineError;
                          final effectiveIsError =
                              _transientStatusMessage != null
                              ? _isTransientError
                              : isPipelineError;
                          final effectiveStatusText =
                              _transientStatusMessage ??
                              (_isEyedropperActive
                                  ? 'MODE: PIXEL EYEDROPPER & LOUPE // [CLICK] COPY HEX // [P/ESC] EXIT'
                                  : _getStatusMessage(c));

                          return RetroStatusBar(
                            statusText: effectiveStatusText,
                            isError: effectiveIsError,
                            dimensions: _naturalSize,
                            zoomScale: _currentScale,
                            currentIndex: c.currentIndex,
                            totalCount: c.playlist.length,
                            sortLabel: c.hasImages
                                ? c.sortCriterionLabel
                                : null,
                            sortDirection: c.hasImages
                                ? c.sortDirectionArrow
                                : null,
                            onSortTap: () {
                              _clearTransientStatus();
                              c.cycleSortCriterion();
                            },
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
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleEscape() {
    if (_isEyedropperActive) {
      setState(() {
        _isEyedropperActive = false;
        _hoveredPixel = null;
        _hoveredScreenPos = null;
        _pixelBuffer = null;
      });
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      exit(0);
    }
  }

  void _showHelpDialog() {
    RetroDialogHelper.showHelpDialog(context);
  }

  Future<void> _showResizeDialog() async {
    final path = widget.controller.currentPath;
    if (path == null) return;
    final size = _naturalSize ?? const Size(800, 600);

    await RetroDialogHelper.showResizeDialog(
      context,
      imagePath: path,
      naturalSize: size,
      onProcessingChanged: (processing) {
        if (mounted && _isResizeProcessing != processing) {
          setState(() => _isResizeProcessing = processing);
        }
      },
      onSaved: (newPath) {
        widget.controller.loadPath(newPath);
        final fileName = newPath.split(Platform.pathSeparator).last;
        _setStatusMessage('SPECIMEN RESIZED: $fileName');
      },
    );
    if (mounted && _isResizeProcessing) {
      setState(() => _isResizeProcessing = false);
    }
  }

  Future<void> _confirmDeleteCurrentFile() async {
    final path = widget.controller.currentPath;
    final name = widget.controller.currentFileName;
    if (path == null || name == null) return;

    final confirmed = await RetroDialogHelper.showDeleteConfirmationDialog(
      context,
      fileName: name,
      filePath: path,
    );

    if (confirmed == true && mounted) {
      final result = await widget.controller.deleteCurrent();
      _handleResult(result);
    }
  }
}

/// Custom ShortcutManager that detects when any editable text field has active focus.
/// In that state, global single-key and clipboard image shortcuts are ignored
/// so typing, pasting, and text editing works seamlessly.
class ViewerShortcutManager extends ShortcutManager {
  ViewerShortcutManager({super.shortcuts});

  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    final primaryFocus = FocusManager.instance.primaryFocus;
    final focusContext = primaryFocus?.context;
    final editable = focusContext?.widget is EditableText
        ? focusContext!.widget as EditableText
        : focusContext?.findAncestorWidgetOfExactType<EditableText>();

    final isWritable = editable != null && !editable.readOnly;
    if (isWritable) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        primaryFocus?.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    return super.handleKeypress(context, event);
  }
}

class _ViewerShortcutIntent extends Intent {
  const _ViewerShortcutIntent(this.callback);
  final VoidCallback callback;
}
