import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum RetroPanelStyle {
  cyanWireframe,
  raisedMetallic,
  sunkenCrt,
  rivetedPlate,
}

class RetroPanel extends StatelessWidget {
  final Widget child;
  final RetroPanelStyle style;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final Color? backgroundColor;
  final double borderWidth;

  const RetroPanel({
    super.key,
    required this.child,
    this.style = RetroPanelStyle.cyanWireframe,
    this.padding,
    this.margin,
    this.borderColor,
    this.backgroundColor,
    this.borderWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    BoxDecoration decoration;

    switch (style) {
      case RetroPanelStyle.cyanWireframe:
        decoration = BoxDecoration(
          color: backgroundColor ?? AppTheme.xCopyCrtBlack,
          border: Border.all(
            color: borderColor ?? context.wireframeCyan,
            width: borderWidth,
          ),
        );
        break;

      case RetroPanelStyle.raisedMetallic:
        decoration = BoxDecoration(
          color: backgroundColor ?? AppTheme.xCopySteel,
          border: Border(
            top: BorderSide(color: AppTheme.xCopySteelLight, width: borderWidth * 2),
            left: BorderSide(color: AppTheme.xCopySteelLight, width: borderWidth * 2),
            bottom: BorderSide(color: AppTheme.xCopySteelDark, width: borderWidth * 2),
            right: BorderSide(color: AppTheme.xCopySteelDark, width: borderWidth * 2),
          ),
        );
        break;

      case RetroPanelStyle.sunkenCrt:
        decoration = BoxDecoration(
          color: backgroundColor ?? AppTheme.xCopyCrtBlack,
          border: Border(
            top: BorderSide(color: AppTheme.xCopySteelDark, width: borderWidth * 2),
            left: BorderSide(color: AppTheme.xCopySteelDark, width: borderWidth * 2),
            bottom: BorderSide(color: AppTheme.xCopySteelLight.withValues(alpha: 0.5), width: borderWidth * 2),
            right: BorderSide(color: AppTheme.xCopySteelLight.withValues(alpha: 0.5), width: borderWidth * 2),
          ),
        );
        break;

      case RetroPanelStyle.rivetedPlate:
        return Container(
          margin: margin,
          child: CustomPaint(
            painter: _RivetBorderPainter(
              borderColor: borderColor ?? context.wireframeCyan,
              bgColor: backgroundColor ?? AppTheme.xCopySteel,
            ),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(12),
              child: child,
            ),
          ),
        );
    }

    return Container(
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: child,
    );
  }
}

class _RivetBorderPainter extends CustomPainter {
  final Color borderColor;
  final Color bgColor;

  _RivetBorderPainter({required this.borderColor, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Outer and inner border lines (X-Copy double line)
    canvas.drawRect(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), borderPaint);
    canvas.drawRect(Rect.fromLTWH(5, 5, size.width - 10, size.height - 10), borderPaint);

    // Draw small rivets between the two border lines
    final rivetPaint = Paint()..color = AppTheme.xCopyRivet;
    final rivetShadow = Paint()..color = AppTheme.xCopyRivetDark;

    const double spacing = 18.0;
    // Top & bottom rivets
    for (double x = 14; x < size.width - 14; x += spacing) {
      _drawRivet(canvas, Offset(x, 3), rivetPaint, rivetShadow);
      _drawRivet(canvas, Offset(x, size.height - 4), rivetPaint, rivetShadow);
    }
    // Left & right rivets
    for (double y = 14; y < size.height - 14; y += spacing) {
      _drawRivet(canvas, Offset(3, y), rivetPaint, rivetShadow);
      _drawRivet(canvas, Offset(size.width - 4, y), rivetPaint, rivetShadow);
    }
  }

  void _drawRivet(Canvas canvas, Offset center, Paint rivet, Paint shadow) {
    canvas.drawCircle(center.translate(0.5, 0.5), 1.6, shadow);
    canvas.drawCircle(center, 1.3, rivet);
  }

  @override
  bool shouldRepaint(covariant _RivetBorderPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor || oldDelegate.bgColor != bgColor;
}
