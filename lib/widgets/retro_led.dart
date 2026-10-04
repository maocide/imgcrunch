import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RetroLed extends StatelessWidget {
  final bool isActive;
  final Color activeColor;
  final Color? inactiveColor;
  final double size;
  final String? label;
  final TextStyle? labelStyle;

  const RetroLed({
    super.key,
    required this.isActive,
    this.activeColor = AppTheme.xCopyAmber,
    this.inactiveColor,
    this.size = 9.0,
    this.label,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final offColor = inactiveColor ?? activeColor.withValues(alpha: 0.25);
    final bulbColor = isActive ? activeColor : offColor;

    final bulb = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bulbColor,
        border: Border.all(
          color: isActive ? Colors.white : AppTheme.xCopySteelLight,
          width: 0.75,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.8),
                  blurRadius: 6,
                  spreadRadius: 1.5,
                ),
              ]
            : null,
      ),
    );

    if (label == null) return bulb;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        bulb,
        const SizedBox(width: 6),
        Text(
          label!,
          style: labelStyle ??
              TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? activeColor : AppTheme.xCopyCyanDim,
                letterSpacing: 1.2,
              ),
        ),
      ],
    );
  }
}
