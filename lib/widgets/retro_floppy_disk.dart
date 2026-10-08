import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A pure procedural vector rendering of a 1992 Amiga 3.5" Floppy Disk (DF0:)
/// with metallic shutter, write-protect notches, paper label, and optional pulsing drive LED.
class RetroFloppyDisk extends StatelessWidget {
  const RetroFloppyDisk({
    super.key,
    this.size = 140.0,
    this.isBlinking = true,
  });

  /// The width of the floppy disk (height is computed via 1:1.04 aspect ratio).
  final double size;

  /// Whether the drive LED below or on the label blinks periodically.
  final bool isBlinking;

  @override
  Widget build(BuildContext context) {
    final height = size * 1.04;

    return SizedBox(
      width: size,
      height: height,
      child: CustomPaint(
        painter: _FloppyDiskPainter(),
      ),
    );
  }
}

class _FloppyDiskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Palette
    const diskColor = Color(0xFF181C24);
    const diskBevelLight = Color(0xFF384050);
    const diskBevelDark = Color(0xFF0A0D12);

    const shutterColor = Color(0xFF5A6577);
    const shutterHighlight = Color(0xFF7E8C9F);
    const shutterShadow = Color(0xFF2C333E);
    const magneticMediaColor = Color(0xFF090B0E);

    const labelBg = Color(0xFFCDD3DC);
    const labelHeader = AppTheme.xCopyCyan;
    const labelText = Color(0xFF14171E);

    // 1. Draw Disk Body Path (with chamfered top-right corner and bottom notches)
    final chamfer = w * 0.08;
    final notchW = w * 0.07;
    final notchH = h * 0.07;

    final bodyPath = Path();
    // Start top-left
    bodyPath.moveTo(0, 0);
    // Top edge to chamfer
    bodyPath.lineTo(w - chamfer, 0);
    // 45-degree chamfer top-right (standard 3.5" disk insertion angle)
    bodyPath.lineTo(w, chamfer);
    // Right edge down to HD notch
    bodyPath.lineTo(w, h - notchH);
    // HD notch right
    bodyPath.lineTo(w - notchW, h - notchH);
    bodyPath.lineTo(w - notchW, h);
    // Bottom edge
    bodyPath.lineTo(notchW, h);
    // Write-protect notch left
    bodyPath.lineTo(notchW, h - notchH);
    bodyPath.lineTo(0, h - notchH);
    bodyPath.close();

    // Drop shadow
    canvas.drawShadow(bodyPath, Colors.black, 8.0, true);

    // Disk base fill
    final diskPaint = Paint()..color = diskColor;
    canvas.drawPath(bodyPath, diskPaint);

    // 2. Bevel highlights (Top/Left light, Bottom/Right dark)
    final lightBevelPaint = Paint()
      ..color = diskBevelLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final lightEdge = Path()
      ..moveTo(0, h - notchH)
      ..lineTo(0, 0)
      ..lineTo(w - chamfer, 0)
      ..lineTo(w, chamfer);
    canvas.drawPath(lightEdge, lightBevelPaint);

    final darkBevelPaint = Paint()
      ..color = diskBevelDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final darkEdge = Path()
      ..moveTo(w, chamfer)
      ..lineTo(w, h - notchH)
      ..lineTo(w - notchW, h - notchH)
      ..lineTo(w - notchW, h)
      ..lineTo(notchW, h);
    canvas.drawPath(darkEdge, darkBevelPaint);

    // 3. Central Drive Spindle Impression
    final centerHub = Offset(w * 0.5, h * 0.44);
    final hubRadius = w * 0.16;
    final hubPaint = Paint()
      ..color = diskBevelDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(centerHub, hubRadius, hubPaint);

    final innerHubPaint = Paint()
      ..color = const Color(0xFF262D38)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centerHub, hubRadius * 0.55, innerHubPaint);

    // 4. Metal Slider Shutter (Top half: x: 0.18w to 0.82w, y: 0 to 0.42h)
    final shutterRect = Rect.fromLTRB(w * 0.18, 0, w * 0.82, h * 0.40);
    final shutterRRect = RRect.fromRectAndRadius(shutterRect, const Radius.circular(2));

    // Shutter background
    final shutterPaint = Paint()..color = shutterColor;
    canvas.drawRRect(shutterRRect, shutterPaint);

    // Shutter bevel
    final shutterHighlightPaint = Paint()
      ..color = shutterHighlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(shutterRRect, shutterHighlightPaint);

    // Shutter groove lines (horizontal brushed metal look)
    final groovePaint = Paint()
      ..color = shutterShadow.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;
    for (var i = 1; i <= 3; i++) {
      final y = h * (0.04 + i * 0.04);
      canvas.drawLine(
        Offset(w * 0.22, y),
        Offset(w * 0.36, y),
        groovePaint,
      );
    }

    // Oblong Read/Write Head Window in Shutter
    final windowRect = Rect.fromLTRB(w * 0.46, h * 0.05, w * 0.66, h * 0.35);
    final windowRRect = RRect.fromRectAndRadius(windowRect, const Radius.circular(3));
    final mediaPaint = Paint()..color = magneticMediaColor;
    canvas.drawRRect(windowRRect, mediaPaint);

    final windowBorderPaint = Paint()
      ..color = shutterShadow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(windowRRect, windowBorderPaint);

    // Magnetic disk inner sheen
    final sheenPaint = Paint()
      ..color = const Color(0xFF1A202C).withValues(alpha: 0.8)
      ..strokeWidth = 3.0;
    canvas.drawLine(
      Offset(w * 0.56, h * 0.07),
      Offset(w * 0.56, h * 0.33),
      sheenPaint,
    );

    // 5. Paper Disk Label (Bottom half)
    final labelRect = Rect.fromLTRB(w * 0.12, h * 0.48, w * 0.88, h * 0.88);
    final labelRRect = RRect.fromRectAndRadius(labelRect, const Radius.circular(2));

    // Label drop shadow/border
    final labelBorder = Paint()
      ..color = diskBevelDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final labelFill = Paint()..color = labelBg;
    canvas.drawRRect(labelRRect, labelFill);
    canvas.drawRRect(labelRRect, labelBorder);

    // Label Header Banner (Cyan stripe)
    final headerRect = Rect.fromLTRB(w * 0.12, h * 0.48, w * 0.88, h * 0.58);
    final headerPaint = Paint()..color = labelHeader;
    canvas.drawRect(headerRect, headerPaint);

    // Label Text ("IMGCRUNCH // 1992" on header, "DF0: NO MEDIA" below)
    final headerTextPainter = TextPainter(
      text: const TextSpan(
        text: 'IMGCRUNCH // 1992',
        style: TextStyle(
          color: Color(0xFF080A0E),
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * 0.74);
    headerTextPainter.paint(
      canvas,
      Offset(w * 0.15, h * 0.50),
    );

    final subTextPainter = TextPainter(
      text: const TextSpan(
        text: 'DF0: [ NO MEDIA ]\nAUTO-CRUNCH READY',
        style: TextStyle(
          color: labelText,
          fontSize: 6.5,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          letterSpacing: 0.3,
          height: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * 0.74);
    subTextPainter.paint(
      canvas,
      Offset(w * 0.15, h * 0.63),
    );

    // Small amber drive indicator mark on the label
    final amberLed = Paint()..color = AppTheme.xCopyAmber;
    canvas.drawCircle(Offset(w * 0.81, h * 0.81), 2.5, amberLed);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
