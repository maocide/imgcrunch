import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProximityFab extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget? menuContent;
  final double triggerRadius;

  const ProximityFab({
    super.key,
    required this.onPressed,
    this.menuContent,
    this.triggerRadius = 140.0,
  });

  @override
  State<ProximityFab> createState() => _ProximityFabState();
}

class _ProximityFabState extends State<ProximityFab> {
  bool _isNear = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      bottom: 0,
      child: MouseRegion(
        opaque: false,
        onEnter: (_) => setState(() => _isNear = true),
        onExit: (_) => setState(() => _isNear = false),
        child: SizedBox(
          width: widget.triggerRadius,
          height: widget.triggerRadius,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: AnimatedOpacity(
                  opacity: _isNear ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: AnimatedScale(
                    scale: _isNear ? 1.0 : 0.6,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: IgnorePointer(
                      ignoring: !_isNear,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: context.theme.brightness == Brightness.dark
                              ? AppTheme.floatingShadow
                              : null,
                        ),
                        child: FloatingActionButton(
                          backgroundColor: context.colors.secondary,
                          foregroundColor: context.colors.onSecondary,
                          elevation: 6,
                          onPressed: widget.onPressed,
                          child: const Icon(Icons.bolt_rounded, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
