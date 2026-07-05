import '../../models/brush_tip_mask.dart';
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
    this.roundness = 1.0,
    this.angleDegrees = 0.0,
    this.tipMask,
  }) : assert(size > 0.0, 'BrushEditCanvasInputSettings.size must be > 0.'),
       assert(
         roundness > 0.0 && roundness <= 1.0,
         'BrushEditCanvasInputSettings.roundness must be in (0, 1].',
       ),
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

  /// Minor-to-major axis ratio of the tip in (0, 1]; 1.0 is the classic
  /// circle/square.
  final double roundness;

  /// Visual counterclockwise rotation of the tip's major axis from the
  /// horizontal, in degrees.
  final double angleDegrees;

  /// Sampled (bitmap) tip; when set it overrides [tipShape] and [hardness].
  final BrushTipMask? tipMask;

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
    double? roundness,
    double? angleDegrees,
    BrushTipMask? tipMask,
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
      roundness: roundness ?? this.roundness,
      angleDegrees: angleDegrees ?? this.angleDegrees,
      tipMask: tipMask ?? this.tipMask,
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
          other.pressureOpacity == pressureOpacity &&
          other.roundness == roundness &&
          other.angleDegrees == angleDegrees &&
          other.tipMask == tipMask;

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
    roundness,
    angleDegrees,
    tipMask,
  );

  @override
  String toString() =>
      'BrushEditCanvasInputSettings(color: $color, size: $size, '
      'opacity: $opacity, flow: $flow, hardness: $hardness, '
      'tipShape: $tipShape, spacing: $spacing, '
      'pressureSize: $pressureSize, pressureOpacity: $pressureOpacity, '
      'roundness: $roundness, angleDegrees: $angleDegrees, '
      'tipMask: $tipMask)';
}
