import 'package:flutter/material.dart';

// DYNAMIC EXTENSION
extension ThemeColors on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;

  // --- Semantic text colors ---
  Color get textHeading => colors.onSurface;
  Color get textBody => colors.onSurface.withValues(alpha: 0.85);
  Color get textSubdued => colors.onSurface.withValues(alpha: 0.55);
  Color get textMuted => colors.onSurface.withValues(alpha: 0.35);
  Color get textDisabled => textMuted;

  // --- X-Copy Pro 1992 Hardware Palette ---
  Color get crtBlack => AppTheme.xCopyCrtBlack;
  Color get wireframeCyan => colors.primary;
  Color get wireframeCyanDim => colors.primary.withValues(alpha: 0.65);
  Color get ledAmber => colors.secondary;
  Color get phosphorGreen => AppTheme.xCopyGreen;
  Color get alertRed => colors.error;
  Color get steelLight => AppTheme.xCopySteelLight;
  Color get steelMid => AppTheme.xCopySteel;
  Color get steelDark => AppTheme.xCopySteelDark;

  // Surface & overlay layers
  Color get backgroundLayer => AppTheme.xCopyCrtBlack;
  Color get surfaceLayer => AppTheme.xCopySteelDark;
  Color get overlayLayer => AppTheme.xCopySteel;
  Color get overlayLayerBright => AppTheme.xCopySteelLight;
  Color get overlayLayerPop => const Color(0xFF323B4A);

  // Border & divider colors
  Color get borderSubtle => wireframeCyan.withValues(alpha: 0.3);
  Color get dividerHard => wireframeCyan;
  Color get textHintLine => colors.onSurface.withValues(alpha: 0.4);

  // Actions and indicators
  Color get subduedActionIcon => wireframeCyan.withValues(alpha: 0.7);
  Color get glowAccent => wireframeCyan.withValues(alpha: 0.4);

  Color get error => colors.error;
  Color get warning => colors.secondary;
}

// THEME FACTORY
class AppTheme {
  // Global floating drop shadow
  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.65),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  // X-COPY Pro (1992) Signature Palette
  static const Color xCopyCyan = Color(0xFF00E5FF);        // 1px Wireframe highlight
  static const Color xCopyCyanDim = Color(0xFF00A2B3);     // Dim wireframe border / secondary labels
  static const Color xCopyAmber = Color(0xFFFFCC00);       // Glowing digital amber
  static const Color xCopyGreen = Color(0xFF00FF66);       // Phosphor CRT terminal green
  static const Color xCopyRed = Color(0xFFFF3333);         // Alert / sync error red
  static const Color xCopyCrtBlack = Color(0xFF05070B);    // Deep cathode black well
  static const Color xCopySteelLight = Color(0xFF5A667A);  // Bevel top/left highlight
  static const Color xCopySteel = Color(0xFF282F3B);       // Brushed chassis panel
  static const Color xCopySteelDark = Color(0xFF141820);   // Bevel bottom/right shadow
  static const Color xCopyRivet = Color(0xFF8896AB);       // Metallic rivet head
  static const Color xCopyRivetDark = Color(0xFF0D1017);   // Rivet inset pit

  static ThemeData buildTheme({Color? primary, Color? secondary}) {
    final activePrimary = primary ?? xCopyCyan;
    final activeSecondary = secondary ?? xCopyAmber;

    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: xCopyCrtBlack,
      colorScheme: ColorScheme.dark(
        primary: activePrimary,
        secondary: activeSecondary,
        tertiary: xCopyGreen,
        surface: xCopySteel,
        error: xCopyRed,
        onPrimary: const Color(0xFF000000),
        onSecondary: const Color(0xFF000000),
        onTertiary: const Color(0xFF000000),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: xCopySteelDark,
        contentTextStyle: const TextStyle(
          color: xCopyGreen,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
        shape: Border.all(color: activePrimary, width: 1.5),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: xCopySteelDark,
        elevation: 0,
        shape: Border.all(color: activePrimary, width: 2.0),
        titleTextStyle: const TextStyle(
          color: xCopyAmber,
          fontFamily: 'monospace',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
        contentTextStyle: const TextStyle(
          color: xCopyGreen,
          fontFamily: 'monospace',
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
