import '../../models/brush_dab.dart';
import '../../models/brush_paint_command.dart';

class BrushSourceStroke {
  BrushSourceStroke({
    required List<BrushDab> sourceDabs,
    this.kind = BrushPaintCommandKind.paintStroke,
  }) : sourceDabs = List<BrushDab>.unmodifiable(sourceDabs);

  final List<BrushDab> sourceDabs;
  final BrushPaintCommandKind kind;
}
