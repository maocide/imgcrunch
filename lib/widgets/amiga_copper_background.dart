import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../controllers/crunch_state_controller.dart';
import '../theme/app_theme.dart';

/// Fullscreen background canvas that displays an authentic Amiga-style
/// fastloader / decruncher raster strobe (ByteKiller / PowerPacker style)
/// with 15kHz CRT scanlines while [isProcessing] is active.
///
/// When idle, renders a pitch-black cathode ray tube background ([AppTheme.xCopyCrtBlack])
/// with 0.0% CPU/GPU overhead.
class AmigaCopperBackground extends StatefulWidget {
  /// Whether an intensive background crunch operation is currently processing.
  final bool isProcessing;

  /// The active view mode, determining the color harmony of the decruncher strobe.
  final ViewMode mode;

  /// The foreground UI widget tree rendered above the decruncher background.
  final Widget child;

  /// Legacy bandHeight parameter preserved for backwards-compatibility.
  final double bandHeight;

  /// Animation cycle ticker duration.
  final Duration cycleDuration;

  /// Chunky scanline quantum step in pixels for authentic CRT beam snapping.
  final double rasterStep;

  /// Pitch of the stationary CRT phosphor scanlines in physical pixels.
  final double scanlineHeight;

  /// Interval in milliseconds between decruncher raster band randomizations (~22-25Hz).
  final int strobeIntervalMs;

  const AmigaCopperBackground({
    super.key,
    required this.isProcessing,
    required this.mode,
    required this.child,
    this.bandHeight = 250.0,
    this.cycleDuration = const Duration(milliseconds: 1000),
    this.rasterStep = 4.0,
    this.scanlineHeight = 2.0,
    this.strobeIntervalMs = 45,
  });

  @override
  State<AmigaCopperBackground> createState() => _AmigaCopperBackgroundState();
}

class _AmigaCopperBackgroundState extends State<AmigaCopperBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.cycleDuration,
    );

    if (widget.isProcessing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AmigaCopperBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cycleDuration != oldWidget.cycleDuration) {
      _controller.duration = widget.cycleDuration;
    }
    if (widget.isProcessing != oldWidget.isProcessing) {
      if (widget.isProcessing) {
        if (!_controller.isAnimating) {
          _controller.repeat();
        }
      } else {
        if (_controller.isAnimating) {
          _controller.stop();
          _controller.reset();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DecruncherRasterPainter(
        repaint: _controller,
        isProcessing: widget.isProcessing,
        mode: widget.mode,
        rasterStep: widget.rasterStep,
        scanlineHeight: widget.scanlineHeight,
        strobeIntervalMs: widget.strobeIntervalMs,
      ),
      child: widget.child,
    );
  }
}

class _DecruncherRasterPainter extends CustomPainter {
  final bool isProcessing;
  final ViewMode mode;
  final double rasterStep;
  final double scanlineHeight;
  final int strobeIntervalMs;

  _DecruncherRasterPainter({
    required Listenable repaint,
    required this.isProcessing,
    required this.mode,
    required this.rasterStep,
    required this.scanlineHeight,
    required this.strobeIntervalMs,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (!isProcessing) {
      // Cathode well idle state: solid black well
      canvas.drawColor(AppTheme.xCopyCrtBlack, BlendMode.src);
      return;
    }

    // Authentic Amiga ByteKiller / PowerPacker Decruncher Raster Strobe:
    // When the 68000 CPU was in its inner decompression loop, it blasted
    // random color values into $DFF180. Because decompression timing was irregular,
    // horizontal solid bands of random heights flashed and jittered across the screen!

    // Determine the discrete decruncher tick from system clock (approx 22-25Hz)
    final tick = DateTime.now().millisecondsSinceEpoch ~/ strobeIntervalMs;
    final rng = math.Random(tick * 31337 + mode.index);
    final palette =
        _decruncherPalettes[mode] ?? _decruncherPalettes[ViewMode.normal]!;

    double y = 0.0;
    final paint = Paint()..style = PaintingStyle.fill;
    final step = rasterStep > 0 ? rasterStep : 4.0;

    while (y < size.height) {
      // Pick random chunky height (1 to 7 chunks: 4px, 8px, 12px, 16px, 20px, 24px, 28px)
      final numSteps = 1 + rng.nextInt(7);
      final bandH = numSteps * step;
      final color = palette[rng.nextInt(palette.length)];

      paint.color = color;
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, bandH), paint);
      y += bandH;
    }

    // Alternate 15kHz CRT horizontal scanline grating with deep cathode grooves (2px dark groove on 4px pitch)
    final scanlineStep = scanlineHeight > 1.0 ? scanlineHeight : 4.0;
    final scanlineShader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, scanlineStep),
      const [
        Color(0x00000000),
        Color(0x00000000),
        Color(
          0x99000000,
        ), // ~60% deep cathode groove (survives LCD motion blur)
        Color(0x99000000),
      ],
      const [0.0, 0.50, 0.50, 1.0],
      TileMode.repeated,
    );

    final scanlinePaint = Paint()
      ..shader = scanlineShader
      ..blendMode = BlendMode.darken;

    canvas.drawRect(rect, scanlinePaint);
  }

  /// Curated 12-bit Amiga decruncher color palettes.
  /// Balanced to be punchy and frantic without blinding pure-white flashes.
  static const Map<ViewMode, List<Color>> _decruncherPalettes = {
    ViewMode.ela: [
      Color(0xFF05070B), // CRT Black
      Color(0xFF00222B), // Deep Teal
      Color(0xFF005566), // Mid Teal
      Color(0xFF0099B3), // Electric Cyan
      Color(0xFF00D4EE), // Bright Cyan
      Color(0xFF2E1700), // Deep Bronze
      Color(0xFF663B00), // Warm Bronze
      Color(0xFFB37700), // Golden Amber
      Color(0xFFFFB300), // Digital Amber
      Color(0xFFFFEE99), // Amber Highlight
      Color(0xFF05070B), // CRT Black
    ],

    ViewMode.ascii: [
      Color(0xFF05070B), // CRT Black
      Color(0xFF001F0A), // Deep Forest
      Color(0xFF003814), // Dark Phosphor
      Color(0xFF006624), // Mid Green
      Color(0xFF009936), // Terminal Green
      Color(0xFF00CC48), // Bright Green
      Color(0xFF00FF5A), // Searing Phosphor Green
      Color(0xFF80FFA5), // Phosphor Highlight
      Color(0xFF05070B), // CRT Black
    ],

    ViewMode.strings: [
      Color(0xFF05070B), // CRT Black
      Color(0xFF261200), // Deep Umber
      Color(0xFF401D00), // Dark Amber
      Color(0xFF733600), // Warm Amber
      Color(0xFF994700), // Mid Amber
      Color(0xFFD66D00), // Amber Gold
      Color(0xFFFF9900), // Digital Amber
      Color(0xFFFFE08A), // Amber Highlight
      Color(0xFF05070B), // CRT Black
    ],

    ViewMode.normal: [
      Color(0xFF05070B), // CRT Black
      Color(0xFF001B24), // Deep Steel
      Color(0xFF003040), // Steel Navy
      Color(0xFF00556B), // Mid Steel
      Color(0xFF0088A8), // Wireframe Cyan
      Color(0xFF00BCE6), // Electric Cyan
      Color(0xFF80ECFF), // Bright Strobe Highlight
      Color(0xFF05070B), // CRT Black
    ],
  };

  @override
  bool shouldRepaint(_DecruncherRasterPainter oldDelegate) {
    return isProcessing != oldDelegate.isProcessing ||
        mode != oldDelegate.mode ||
        rasterStep != oldDelegate.rasterStep ||
        scanlineHeight != oldDelegate.scanlineHeight ||
        strobeIntervalMs != oldDelegate.strobeIntervalMs;
  }
}
