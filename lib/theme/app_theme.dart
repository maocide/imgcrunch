import 'package:flutter/material.dart';

// DYNAMIC EXTENSION
extension ThemeColors on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;

  // --- Semantic text colors ---
  Color get textHeading => colors.onSurface;
  Color get textBody => colors.onSurface.withValues(alpha: 0.8);
  Color get textSubdued => colors.onSurface.withValues(alpha: 0.5);
  Color get textMuted => colors.onSurface.withValues(alpha: 0.3);
  Color get textDisabled => textMuted;

  // --- Surface & overlay colors ---
  Color get glassBg => colors.surface.withValues(alpha: 0.4);

  // Elevation system (Lerping towards White)
  Color get backgroundLayer => const Color(0xFF121212);
  Color get surfaceLayer => Color.lerp(backgroundLayer, Colors.white, 0.03)!;
  Color get overlayLayer => Color.lerp(backgroundLayer, Colors.white, 0.05)!;
  Color get overlayLayerBright =>
      Color.lerp(backgroundLayer, Colors.white, 0.08)!;
  Color get overlayLayerPop => Color.lerp(backgroundLayer, Colors.white, 0.14)!;

  // --- Border & divider colors ---
  Color get borderSubtle => colors.onSurface.withValues(alpha: 0.08);
  Color get dividerHard => colors.onSurface.withValues(alpha: 0.3);
  Color get textHintLine => colors.onSurface.withValues(alpha: 0.4);

  // --- Primary/secondary with alpha helpers ---
  Color primaryWithAlpha(double a) => colors.primary.withValues(alpha: a);
  Color secondaryWithAlpha(double a) => colors.secondary.withValues(alpha: a);

  // Actions and indicators
  Color get subduedActionIcon => colors.secondary.withValues(alpha: 0.6);
  Color get glowAccent => colors.secondary.withValues(alpha: 0.35);

  Color get error => colors.error;
  Color get warning => colors.tertiary;
}

// THEME FACTORY
class AppTheme {
  // Global floating drop shadow
  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.45),
      blurRadius: 18,
      offset: const Offset(0, 4),
    ),
  ];

  // Static foundations
  static const Color baseGrey = Color(0xFF161616);
  static const Color surfaceDark = Color(0xFF1E1E24);

  // Default Cyber / Forensics Neon identity
  static const Color defaultPrimary = Color(0xFFFF85B3); // Neon Pink
  static const Color defaultSecondary = Color(0xFF00E0E0); // Forensic Cyan
  static const Color defaultTertiary = Color(0xFFFED83A); // Warning Amber

  static ThemeData buildTheme({Color? primary, Color? secondary}) {
    final activePrimary = primary ?? defaultPrimary;
    final activeSecondary = secondary ?? defaultSecondary;

    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: ColorScheme.dark(
        primary: activePrimary,
        secondary: activeSecondary,
        tertiary: defaultTertiary,
        surface: baseGrey,
        error: defaultTertiary,
        onPrimary: const Color(0xFF000000),
        onSecondary: const Color(0xFF000000),
        onTertiary: const Color(0xFF000000),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: baseGrey,
        contentTextStyle: TextStyle(color: activePrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: baseGrey,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: activePrimary.withValues(alpha: 0.5),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: TextStyle(
          color: activePrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 14,
        ),
      ),
    );
  }
}
