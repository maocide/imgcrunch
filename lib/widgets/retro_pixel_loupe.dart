import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'retro_led.dart';
import 'retro_panel.dart';

/// Floating CRT loupe and pixel inspector HUD widget.
///
/// Displays a magnified 9x9 pixel patch centered on the sampled pixel with
/// reticle crosshair, scanlines, color swatch chip, and HEX/RGB/coordinate readout.
/// Automatically clamps and flips position to avoid clipping at viewport edges.
class RetroPixelLoupe extends StatelessWidget {
  final Point<int> pixelCoordinates;
  final Color color;
  final String hexCode;
  final String rgbText;
  final List<List<Color>> patch;
  final Offset screenPosition;
  final Size viewportSize;

  const RetroPixelLoupe({
    super.key,
    required this.pixelCoordinates,
    required this.color,
    required this.hexCode,
    required this.rgbText,
    required this.patch,
    required this.screenPosition,
    required this.viewportSize,
  });

  static const double loupeWidth = 260.0;
  static const double loupeHeight = 175.0;
  static const double cursorOffset = 22.0;

  @override
  Widget build(BuildContext context) {
    // Calculate clamped/flipped coordinates so loupe remains visible within viewport
    double left = screenPosition.dx + cursorOffset;
    double top = screenPosition.dy + cursorOffset;

    if (left + loupeWidth > viewportSize.width - 12) {
      left = screenPosition.dx - loupeWidth - cursorOffset;
    }
    if (left < 12) {
      left = 12;
    }

    if (top + loupeHeight > viewportSize.height - 12) {
      top = screenPosition.dy - loupeHeight - cursorOffset;
    }
    if (top < 12) {
      top = 12;
    }

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: loupeWidth,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 18,
                offset: const Offset(4, 6),
              ),
            ],
          ),
          child: RetroPanel(
            style: RetroPanelStyle.sunkenCrt,
            backgroundColor: AppTheme.xCopyCrtBlack.withValues(alpha: 0.95),
            borderColor: AppTheme.xCopyCyan,
            borderWidth: 1.5,
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with LED indicator
                Row(
                  children: [
                    const RetroLed(
                      isActive: true,
                      activeColor: AppTheme.xCopyAmber,
                      size: 6,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LOUPE 9x9',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppTheme.xCopyAmber,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'P: ${pixelCoordinates.x},${pixelCoordinates.y}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.xCopyCyanDim,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Magnified pixel grid (108 x 108 px)
                    Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.xCopySteelLight,
                          width: 1,
                        ),
                      ),
                      child: CustomPaint(
                        painter: _PixelGridPainter(
                          patch: patch,
                          centerBorderColor: AppTheme.xCopyAmber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Inspector Details & Swatch
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Color Swatch Box
                          Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.7),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hexCode,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'RGB: $rgbText',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: AppTheme.xCopyAmber,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'X: ${pixelCoordinates.x} Y: ${pixelCoordinates.y}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: AppTheme.xCopyGreen,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.xCopySteelDark,
                              border: Border.all(
                                color: AppTheme.xCopyCyanDim,
                                width: 0.5,
                              ),
                            ),
                            child: const Text(
                              '[CLICK] COPY',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.xCopyCyan,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelGridPainter extends CustomPainter {
  final List<List<Color>> patch;
  final Color centerBorderColor;

  const _PixelGridPainter({
    required this.patch,
    required this.centerBorderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rows = patch.length;
    if (rows == 0) return;
    final cols = patch[0].length;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    final cellPaint = Paint()..style = PaintingStyle.fill;
    final gridLinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH);
        cellPaint.color = patch[r][c];
        canvas.drawRect(rect, cellPaint);
        canvas.drawRect(rect, gridLinePaint);
      }
    }

    // Highlight center pixel with a bold reticle box
    final centerR = rows ~/ 2;
    final centerC = cols ~/ 2;
    final centerRect = Rect.fromLTWH(
      centerC * cellW,
      centerR * cellH,
      cellW,
      cellH,
    );

    final reticlePaint = Paint()
      ..color = centerBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(centerRect, reticlePaint);

    // Scanline mesh overlay
    final scanlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PixelGridPainter oldDelegate) {
    return oldDelegate.patch != patch ||
        oldDelegate.centerBorderColor != centerBorderColor;
  }
}
