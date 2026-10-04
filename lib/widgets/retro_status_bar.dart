import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RetroStatusBar extends StatelessWidget {
  final String statusText;
  final String? secondaryText;
  final double? zoomScale;
  final int? currentIndex;
  final int? totalCount;
  final Widget? trailing;

  const RetroStatusBar({
    super.key,
    required this.statusText,
    this.secondaryText,
    this.zoomScale,
    this.currentIndex,
    this.totalCount,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final zoomStr = zoomScale != null ? '${(zoomScale! * 100).toInt()}%' : null;
    final trackStr =
        (currentIndex != null && totalCount != null && totalCount! > 0)
        ? '${currentIndex! + 1}/${totalCount!}'
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.xCopyCrtBlack,
        border: Border.all(color: AppTheme.xCopyCyan, width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final isCompact = w < 480;
          final showZoom = w > 360 && zoomStr != null;
          final showTrack = w > 270 && trackStr != null;
          final showSecondary = w > 520 && secondaryText != null;

          final zoomPrefix = isCompact ? 'Z: ' : 'ZOOM: ';
          final trackPrefix = isCompact ? 'TRK: ' : 'TRACK: ';

          return Row(
            children: [
              // Green phosphor status terminal text
              const Text(
                '> ',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.xCopyAmber,
                ),
              ),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: AppTheme.xCopyGreen,
                  ),
                ),
              ),

              if (showSecondary) ...[
                const SizedBox(width: 10),
                Text(
                  secondaryText!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppTheme.xCopyCyan,
                    letterSpacing: 0.8,
                  ),
                ),
              ],

              if (showZoom) ...[
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      zoomPrefix,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.xCopyCyanDim,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      zoomStr,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.xCopyAmber,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],

              if (showTrack) ...[
                const SizedBox(width: 12),
                Flexible(
                  flex: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        trackPrefix,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppTheme.xCopyCyanDim,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          trackStr,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.xCopyAmber,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          );
        },
      ),
    );
  }
}
