import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RetroButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color textColor;
  final Color? borderColor;
  final String? shortcut;
  final IconData? icon;
  final bool isSelected;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  const RetroButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.textColor = AppTheme.xCopyAmber,
    this.borderColor,
    this.shortcut,
    this.icon,
    this.isSelected = false,
    this.fontSize = 11.0,
    this.padding,
  });

  @override
  State<RetroButton> createState() => _RetroButtonState();
}

class _RetroButtonState extends State<RetroButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final activeText = enabled
        ? (widget.isSelected ? Colors.black : widget.textColor)
        : AppTheme.xCopySteelLight;
    final activeBorder = enabled
        ? (_isHovered
            ? Colors.white
            : (widget.isSelected
                ? Colors.white
                : (widget.borderColor ?? context.wireframeCyan)))
        : AppTheme.xCopySteelDark;
    final activeBg = widget.isSelected
        ? widget.textColor
        : (_isPressed
            ? AppTheme.xCopySteel
            : (_isHovered
                ? AppTheme.xCopySteel.withValues(alpha: 0.5)
                : AppTheme.xCopyCrtBlack));

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onPressed,
        child: Container(
          padding: widget.padding ??
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: activeBg,
            border: Border.all(color: activeBorder, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: widget.fontSize + 2, color: activeText),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: activeText,
                ),
              ),
              if (widget.shortcut != null) ...[
                const SizedBox(width: 4),
                Text(
                  '(${widget.shortcut})',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: widget.fontSize - 2,
                    fontWeight: FontWeight.w600,
                    color: activeText.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
