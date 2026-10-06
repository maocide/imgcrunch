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
                padding: const EdgeInsets.only(right: 18.0, bottom: 42.0),
                child: AnimatedOpacity(
                  opacity: _isNear ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOut,
                  child: AnimatedScale(
                    scale: _isNear ? 1.0 : 0.7,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack,
                    child: IgnorePointer(
                      ignoring: !_isNear,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.xCopyCrtBlack.withValues(alpha: 0.80),
                          border: Border.all(
                            color: context.wireframeCyan,
                            width: 1.5,
                          ),
                          boxShadow: AppTheme.floatingShadow,
                        ),
                        child: InkWell(
                          onTap: widget.onPressed,
                          child: const Center(
                            child: Icon(
                              Icons.bolt_rounded,
                              size: 22,
                              color: AppTheme.xCopyAmber,
                            ),
                          ),
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
