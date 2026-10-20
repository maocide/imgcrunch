import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RetroStatusBar extends StatelessWidget {
  final String statusText;
  final String? secondaryText;
  final Size? dimensions;
  final double? zoomScale;
  final int? currentIndex;
  final int? totalCount;
  final String? sortLabel;
  final String? sortDirection;
  final VoidCallback? onSortTap;
  final Widget? trailing;

  const RetroStatusBar({
    super.key,
    required this.statusText,
    this.secondaryText,
    this.dimensions,
    this.zoomScale,
    this.currentIndex,
    this.totalCount,
    this.sortLabel,
    this.sortDirection,
    this.onSortTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final resStr = dimensions != null
        ? '${dimensions!.width.toInt()}x${dimensions!.height.toInt()}'
        : null;
    final zoomStr = zoomScale != null ? '${(zoomScale! * 100).toInt()}%' : null;
    final trackStr =
        (currentIndex != null && totalCount != null && totalCount! > 0)
        ? '${currentIndex! + 1}/${totalCount!}'
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: context.wireframeCyan, width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final isCompact = w < 480;
          final showResolution = w > 520 && resStr != null;
          final showZoom = w > 360 && zoomStr != null;
          final showTrack = w > 270 && trackStr != null;
          final showSort = w > 380 && sortLabel != null;
          final showSecondary = w > 640 && secondaryText != null;

          final resPrefix = isCompact ? 'R: ' : 'RES: ';
          final zoomPrefix = isCompact ? 'Z: ' : 'ZOOM: ';
          final trackPrefix = isCompact ? 'TRK: ' : 'TRACK: ';
          final sortPrefix = isCompact ? 'S: ' : 'SORT: ';

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
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: context.wireframeCyan,
                    letterSpacing: 0.8,
                  ),
                ),
              ],

              if (showResolution) ...[
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      resPrefix,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: context.wireframeCyanDim,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      resStr,
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

              if (showZoom) ...[
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      zoomPrefix,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: context.wireframeCyanDim,
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
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: context.wireframeCyanDim,
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

              if (showSort) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: onSortTap,
                  borderRadius: BorderRadius.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sortPrefix,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: context.wireframeCyanDim,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        '$sortLabel ${sortDirection ?? ""}'.trim(),
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
