import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/rust_image_service.dart';
import '../theme/app_theme.dart';
import '../utils/file_naming_helper.dart';
import 'retro_button.dart';
import 'retro_led.dart';
import 'retro_panel.dart';

/// Modal dialog for interactive, high-quality Lanczos3 image resizing
/// with bidirectional percentage fader and exact pixel controls.
class RetroResizeDialog extends StatefulWidget {
  const RetroResizeDialog({
    super.key,
    required this.imagePath,
    required this.naturalSize,
    required this.onSaved,
    this.onProcessingChanged,
  });

  final String imagePath;
  final Size naturalSize;
  final ValueChanged<String> onSaved;
  final ValueChanged<bool>? onProcessingChanged;

  /// Convenience runner to show the dialog modally.
  static Future<void> show(
    BuildContext context, {
    required String imagePath,
    required Size naturalSize,
    required ValueChanged<String> onSaved,
    ValueChanged<bool>? onProcessingChanged,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => RetroResizeDialog(
        imagePath: imagePath,
        naturalSize: naturalSize,
        onSaved: onSaved,
        onProcessingChanged: onProcessingChanged,
      ),
    );
  }

  @override
  State<RetroResizeDialog> createState() => _RetroResizeDialogState();
}

class _RetroResizeDialogState extends State<RetroResizeDialog> {
  static const List<double> _presets = [25.0, 50.0, 75.0, 100.0, 150.0, 200.0];

  late final int _origW;
  late final int _origH;
  late final double _aspectRatio;

  late final TextEditingController _widthCtrl;
  late final TextEditingController _heightCtrl;

  double _currentPercent = 100.0;
  bool _isAspectLocked = true;
  bool _isProcessing = false;
  bool _isInternalUpdate = false;
  String? _errorMessage;
  late String _outputPath;

  @override
  void initState() {
    super.initState();
    _origW = widget.naturalSize.width > 0
        ? widget.naturalSize.width.toInt()
        : 800;
    _origH = widget.naturalSize.height > 0
        ? widget.naturalSize.height.toInt()
        : 600;
    _aspectRatio = _origW / _origH;

    _widthCtrl = TextEditingController(text: '$_origW');
    _heightCtrl = TextEditingController(text: '$_origH');

    _outputPath = FileNamingHelper.computeIncrementalPath(
      widget.imagePath,
      opTag: 'resized',
      targetExtension: 'png',
    );
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  void _applyPercent(double percent) {
    // Magnetic snap to preset points if within +/- 3.0%
    double target = percent;
    for (final p in _presets) {
      if ((percent - p).abs() <= 3.0) {
        target = p;
        break;
      }
    }

    final newW = (_origW * (target / 100.0)).round().clamp(1, 65535);
    final newH = (_origH * (target / 100.0)).round().clamp(1, 65535);

    _isInternalUpdate = true;
    setState(() {
      _currentPercent = target;
      _widthCtrl.text = '$newW';
      _heightCtrl.text = '$newH';
      _errorMessage = null;
    });
    _isInternalUpdate = false;
  }

  void _onWidthChanged(String text) {
    if (_isInternalUpdate) return;
    final w = int.tryParse(text.trim());
    if (w == null || w <= 0) return;

    _isInternalUpdate = true;
    setState(() {
      _currentPercent = (w / _origW * 100.0).clamp(1.0, 500.0);
      if (_isAspectLocked) {
        final newH = (w / _aspectRatio).round().clamp(1, 65535);
        _heightCtrl.text = '$newH';
      }
      _errorMessage = null;
    });
    _isInternalUpdate = false;
  }

  void _onHeightChanged(String text) {
    if (_isInternalUpdate) return;
    final h = int.tryParse(text.trim());
    if (h == null || h <= 0) return;

    _isInternalUpdate = true;
    setState(() {
      if (_isAspectLocked) {
        final newW = (h * _aspectRatio).round().clamp(1, 65535);
        _widthCtrl.text = '$newW';
        _currentPercent = (newW / _origW * 100.0).clamp(1.0, 500.0);
      } else {
        _currentPercent = (h / _origH * 100.0).clamp(1.0, 500.0);
      }
      _errorMessage = null;
    });
    _isInternalUpdate = false;
  }

  Future<void> _executeResize() async {
    if (_isProcessing) return;
    _isProcessing = true;
    widget.onProcessingChanged?.call(true);

    FocusScope.of(context).unfocus();

    final targetW = int.tryParse(_widthCtrl.text.trim());
    final targetH = int.tryParse(_heightCtrl.text.trim());

    if (targetW == null || targetW <= 0 || targetH == null || targetH <= 0) {
      widget.onProcessingChanged?.call(false);
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Invalid dimensions specified.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      final file = File(widget.imagePath);
      if (!await file.exists()) {
        throw FileSystemException(
          'Source specimen not found',
          widget.imagePath,
        );
      }

      final rawBytes = await file.readAsBytes();
      final resizedBytes = await RustImageService.instance.resizeImageFromBytes(
        rawBytes,
        width: targetW,
        height: targetH,
      );

      final outFile = File(_outputPath);
      await outFile.writeAsBytes(resizedBytes);

      if (mounted) {
        widget.onProcessingChanged?.call(false);
        Navigator.of(context).pop();
        widget.onSaved(_outputPath);
      }
    } catch (e) {
      widget.onProcessingChanged?.call(false);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Resize failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.imagePath.split(Platform.pathSeparator).last;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_isProcessing) _executeResize();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_isProcessing) _executeResize();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_isProcessing) Navigator.of(context).pop();
        },
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: RetroPanel(
              style: RetroPanelStyle.rivetedPlate,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      const RetroLed(
                        isActive: true,
                        activeColor: AppTheme.xCopyAmber,
                        size: 8,
                      ),
                      Expanded(
                        child: Text(
                          'IMGCRUNCH // RESIZE IMAGE (LANCZOS3)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: context.wireframeCyan,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: context.wireframeCyanDim,
                          size: 18,
                        ),
                        onPressed: _isProcessing
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 1,
                    color: context.wireframeCyanDim.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 14),

                  // Specimen summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'SPECIMEN: $fileName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '[$_origW × $_origH PX]',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.xCopyAmber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Slider & Scale Readout
                  Row(
                    children: [
                      const Text(
                        'SCALE FACTOR:',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.xCopyCrtBlack,
                          border: Border.all(
                            color: AppTheme.xCopyAmber.withValues(alpha: 0.6),
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '${_currentPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.xCopyAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.xCopyAmber,
                      inactiveTrackColor: AppTheme.xCopySteelDark,
                      thumbColor: AppTheme.xCopyAmber,
                      overlayColor: AppTheme.xCopyAmber.withValues(alpha: 0.2),
                      trackHeight: 3.0,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7.0,
                      ),
                    ),
                    child: Slider(
                      value: _currentPercent.clamp(10.0, 250.0),
                      min: 10.0,
                      max: 250.0,
                      onChanged: _isProcessing ? null : _applyPercent,
                    ),
                  ),

                  // Quick preset pills
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: _presets.map((p) {
                      final isSelected = (_currentPercent - p).abs() < 1.0;
                      return RetroButton(
                        label: '${p.toInt()}%',
                        fontSize: 10,
                        isSelected: isSelected,
                        textColor: isSelected
                            ? Colors.black
                            : AppTheme.xCopyCyan,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        onPressed: _isProcessing
                            ? null
                            : () => _applyPercent(p),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Exact Pixel Inputs + Aspect Lock
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WIDTH [PX]',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildDimensionField(_widthCtrl, _onWidthChanged),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Aspect lock button
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Tooltip(
                          message: _isAspectLocked
                              ? 'Aspect Ratio Locked (Proportional)'
                              : 'Aspect Ratio Unlocked (Freeform)',
                          child: RetroButton(
                            label: _isAspectLocked ? 'LINKED' : 'UNLINK',
                            icon: _isAspectLocked ? Icons.link : Icons.link_off,
                            fontSize: 10,
                            textColor: _isAspectLocked
                                ? AppTheme.xCopyAmber
                                : AppTheme.xCopySteelLight,
                            borderColor: _isAspectLocked
                                ? AppTheme.xCopyAmber
                                : AppTheme.xCopySteelDark,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            onPressed: _isProcessing
                                ? null
                                : () {
                                    setState(() {
                                      _isAspectLocked = !_isAspectLocked;
                                      if (_isAspectLocked) {
                                        final w =
                                            int.tryParse(
                                              _widthCtrl.text.trim(),
                                            ) ??
                                            _origW;
                                        final newH = (w / _aspectRatio)
                                            .round()
                                            .clamp(1, 65535);
                                        _heightCtrl.text = '$newH';
                                      }
                                    });
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'HEIGHT [PX]',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildDimensionField(_heightCtrl, _onHeightChanged),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Destination path readout
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.xCopyCrtBlack,
                      border: Border.all(
                        color: context.wireframeCyanDim.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TARGET FILE:',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            color: AppTheme.xCopyCyanDim,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _outputPath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: AppTheme.xCopyGreen,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error display
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.xCopyRed,
                      ),
                    ),
                  ],

                  // Processing feedback
                  if (_isProcessing) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'CRUNCHING LANCZOS3 SCALING & STREAMING TO DISK...',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.xCopyAmber,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Dialog Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      RetroButton(
                        label: 'CANCEL',
                        shortcut: 'ESC',
                        textColor: AppTheme.xCopyRed,
                        onPressed: _isProcessing
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      RetroButton(
                        label: _isProcessing ? 'RESIZING...' : 'RESIZE & SAVE',
                        shortcut: 'ENTER',
                        textColor: AppTheme.xCopyAmber,
                        isSelected: true,
                        onPressed: _isProcessing ? null : _executeResize,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDimensionField(
    TextEditingController controller,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppTheme.xCopyCrtBlack,
        border: Border.all(color: context.wireframeCyanDim),
        borderRadius: BorderRadius.circular(2),
      ),
      child: TextField(
        controller: controller,
        enabled: !_isProcessing,
        keyboardType: TextInputType.number,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.xCopyGreen,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: InputBorder.none,
        ),
        onChanged: onChanged,
        onSubmitted: (_) {
          if (!_isProcessing) _executeResize();
        },
      ),
    );
  }
}
