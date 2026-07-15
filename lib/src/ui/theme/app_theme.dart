import 'package:flutter/material.dart';

/// The app-wide dark palette (TVPaint/OpenToonz-style flat charcoal).
///
/// Every UI color that is not derived from [ColorScheme] at build time should
/// reference one of these constants so the palette stays adjustable in one
/// place. The accent is deliberately a single hue used sparingly: playhead,
/// selection, active states.
abstract final class AppColors {
  /// Accent (teal) — selection, playhead, active toggles.
  static const Color accent = Color(0xFF4FA8A0);

  /// Darkest backdrop: canvas surround, scaffold background.
  static const Color backdrop = Color(0xFF141517);

  /// Panel body surface.
  static const Color surface = Color(0xFF1E2022);

  /// Panel headers and toolbars.
  static const Color surfaceRaised = Color(0xFF26282B);

  /// Hover fills and exposure blocks — one step above raised.
  static const Color surfaceHigh = Color(0xFF303336);

  /// Hairline borders between panels and cells.
  static const Color hairline = Color(0xFF37393C);

  /// Emphasized borders (block outlines, dividers that must read clearly).
  static const Color hairlineStrong = Color(0xFF45494E);

  /// Primary text and icons.
  static const Color text = Color(0xFFB4B8BB);

  /// Secondary text and inactive icons.
  static const Color textDim = Color(0xFF7C8184);

  /// Muted red for destructive/warning marks (cut-end boundary).
  static const Color danger = Color(0xFFC95C5C);
}

/// Every popup menu opens INSTANTLY (R4 #2): Material's default grow +
/// staggered item fade read as entries appearing one by one — pass this to
/// each `showMenu`/`PopupMenuButton` as `popUpAnimationStyle`.
const AnimationStyle instantMenuAnimation = AnimationStyle(
  duration: Duration.zero,
  reverseDuration: Duration.zero,
);

ColorScheme _buildColorScheme() {
  return const ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.accent,
    onPrimary: Color(0xFF10201E),
    primaryContainer: Color(0xFF27443F),
    onPrimaryContainer: Color(0xFFA5D6D0),
    secondary: AppColors.accent,
    onSecondary: Color(0xFF10201E),
    secondaryContainer: Color(0xFF2A3A38),
    onSecondaryContainer: Color(0xFFA5D6D0),
    error: AppColors.danger,
    onError: Color(0xFF2B1212),
    surface: AppColors.surface,
    onSurface: AppColors.text,
    surfaceDim: AppColors.backdrop,
    surfaceContainerLowest: AppColors.backdrop,
    surfaceContainerLow: Color(0xFF1A1C1E),
    surfaceContainer: Color(0xFF232527),
    surfaceContainerHigh: AppColors.surfaceHigh,
    surfaceContainerHighest: AppColors.surfaceRaised,
    onSurfaceVariant: AppColors.textDim,
    outline: AppColors.hairlineStrong,
    outlineVariant: AppColors.hairline,
  );
}

/// The single app theme: flat dark surfaces, hairline borders, compact
/// icon-first controls with tooltips.
ThemeData buildAppTheme() {
  final colorScheme = _buildColorScheme();
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.backdrop,
    canvasColor: AppColors.surface,
    dividerColor: AppColors.hairline,
    visualDensity: VisualDensity.compact,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceRaised,
      foregroundColor: AppColors.text,
      elevation: 0,
      toolbarHeight: 40,
      titleTextStyle: TextStyle(
        color: AppColors.textDim,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.text, size: 20),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.text,
        disabledForegroundColor: AppColors.textDim.withValues(alpha: 0.5),
        iconSize: 20,
        padding: const EdgeInsets.all(6),
        minimumSize: const Size(32, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.text,
        disabledForegroundColor: AppColors.textDim.withValues(alpha: 0.5),
      ),
    ),
    scrollbarTheme: const ScrollbarThemeData(
      thumbVisibility: WidgetStatePropertyAll<bool>(true),
      trackVisibility: WidgetStatePropertyAll<bool>(true),
      thickness: WidgetStatePropertyAll<double>(6),
      radius: Radius.circular(3),
      thumbColor: WidgetStatePropertyAll<Color>(AppColors.hairlineStrong),
      trackColor: WidgetStatePropertyAll<Color>(Color(0xFF232527)),
      trackBorderColor: WidgetStatePropertyAll<Color>(Colors.transparent),
      crossAxisMargin: 2,
      mainAxisMargin: 2,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppColors.hairline),
      ),
      textStyle: const TextStyle(color: AppColors.text, fontSize: 12),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      textStyle: TextStyle(color: AppColors.text, fontSize: 12),
    ),
  );
}
