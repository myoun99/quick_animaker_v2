import '../../models/brush_tip_shape.dart';

class BrushEditCanvasInputSettings {
  const BrushEditCanvasInputSettings({
    this.color = 0xFF000000,
    this.size = 1.0,
    this.opacity = 1.0,
    this.flow = 1.0,
    this.hardness = 1.0,
    this.tipShape = BrushTipShape.round,
    this.spacing = 0.25,
    this.pressureSize = false,
    this.pressureOpacity = false,
  }) : assert(size > 0.0, 'BrushEditCanvasInputSettings.size must be > 0.'),
       assert(
         opacity >= 0.0 && opacity <= 1.0,
         'BrushEditCanvasInputSettings.opacity must be between 0 and 1.',
       ),
       assert(
         flow >= 0.0 && flow <= 1.0,
         'BrushEditCanvasInputSettings.flow must be between 0 and 1.',
       ),
       assert(
         hardness >= 0.0 && hardness <= 1.0,
         'BrushEditCanvasInputSettings.hardness must be between 0 and 1.',
       ),
       assert(
         spacing > 0.0,
         'BrushEditCanvasInputSettings.spacing must be > 0.',
       );

  final int color;
  final double size;
  final double opacity;
  final double flow;
  final double hardness;
  final BrushTipShape tipShape;
  final double spacing;

  /// When true, each dab's size is scaled by the input pressure (linear).
  final bool pressureSize;

  /// When true, each dab's opacity is scaled by the input pressure (linear).
  final bool pressureOpacity;

  BrushEditCanvasInputSettings copyWith({
    int? color,
    double? size,
    double? opacity,
    double? flow,
    double? hardness,
    BrushTipShape? tipShape,
    double? spacing,
    bool? pressureSize,
    bool? pressureOpacity,
  }) {
    return BrushEditCanvasInputSettings(
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      flow: flow ?? this.flow,
      hardness: hardness ?? this.hardness,
      tipShape: tipShape ?? this.tipShape,
      spacing: spacing ?? this.spacing,
      pressureSize: pressureSize ?? this.pressureSize,
      pressureOpacity: pressureOpacity ?? this.pressureOpacity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushEditCanvasInputSettings &&
          other.color == color &&
          other.size == size &&
          other.opacity == opacity &&
          other.flow == flow &&
          other.hardness == hardness &&
          other.tipShape == tipShape &&
          other.spacing == spacing &&
          other.pressureSize == pressureSize &&
          other.pressureOpacity == pressureOpacity;

  @override
  int get hashCode => Object.hash(
    color,
    size,
    opacity,
    flow,
    hardness,
    tipShape,
    spacing,
    pressureSize,
    pressureOpacity,
  );

  @override
  String toString() =>
      'BrushEditCanvasInputSettings(color: $color, size: $size, '
      'opacity: $opacity, flow: $flow, hardness: $hardness, '
      'tipShape: $tipShape, spacing: $spacing, '
      'pressureSize: $pressureSize, pressureOpacity: $pressureOpacity)';
}
