import '../canvas/brush_edit_canvas_input_settings.dart';

/// Editor-session state for the active brush tool options.
///
/// This is UI/tool state owned by the editor session. It is intentionally
/// separate from project, cut, layer, frame, stroke, cache, and save/load data.
class BrushToolState {
  factory BrushToolState({
    double size = defaultSize,
    double opacity = defaultOpacity,
    int color = defaultColor,
    double spacing = defaultSpacing,
  }) {
    return BrushToolState.clamped(
      size: size,
      opacity: opacity,
      color: color,
      spacing: spacing,
    );
  }

  const BrushToolState._raw({
    required this.size,
    required this.opacity,
    required this.color,
    required this.spacing,
  });

  factory BrushToolState.clamped({
    double? size,
    double? opacity,
    int? color,
    double? spacing,
  }) {
    return BrushToolState._raw(
      size: clampSize(size ?? defaultSize),
      opacity: clampOpacity(opacity ?? defaultOpacity),
      color: color ?? defaultColor,
      spacing: clampSpacing(spacing ?? defaultSpacing),
    );
  }

  static const double minSize = 1.0;
  static const double maxSize = 128.0;
  static const double defaultSize = 10.0;
  static const double defaultOpacity = 1.0;
  static const int defaultColor = 0xFF000000;
  static const double minSpacing = 0.05;
  static const double maxSpacing = 4.0;
  static const double defaultSpacing = 0.25;
  static const BrushToolState defaults = BrushToolState._raw(
    size: defaultSize,
    opacity: defaultOpacity,
    color: defaultColor,
    spacing: defaultSpacing,
  );

  final double size;
  final double opacity;
  final int color;
  final double spacing;

  BrushEditCanvasInputSettings toInputSettings() {
    return BrushEditCanvasInputSettings(
      color: color,
      size: size,
      opacity: opacity,
      spacing: spacing,
    );
  }

  BrushToolState copyWith({
    double? size,
    double? opacity,
    int? color,
    double? spacing,
  }) {
    return BrushToolState.clamped(
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      color: color ?? this.color,
      spacing: spacing ?? this.spacing,
    );
  }

  static double clampSize(double value) {
    if (!value.isFinite) {
      return defaultSize;
    }
    return value.clamp(minSize, maxSize).toDouble();
  }

  static double clampOpacity(double value) {
    if (!value.isFinite) {
      return defaultOpacity;
    }
    return value.clamp(0.0, 1.0).toDouble();
  }

  static double clampSpacing(double value) {
    if (!value.isFinite) {
      return defaultSpacing;
    }
    return value.clamp(minSpacing, maxSpacing).toDouble();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushToolState &&
          other.size == size &&
          other.opacity == opacity &&
          other.color == color &&
          other.spacing == spacing;

  @override
  int get hashCode => Object.hash(size, opacity, color, spacing);
}
