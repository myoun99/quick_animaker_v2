import 'brush_paint_command_id.dart';
import 'brush_paint_command_state.dart';

enum BrushPaintCommandKind {
  paintStroke,
  eraseStroke,
  clearFrameDrawing,
  fillFrameDrawing,
}

class BrushPaintCommand {
  const BrushPaintCommand({
    required this.id,
    required this.sequenceNumber,
    required this.kind,
    this.state = BrushPaintCommandState.live,
    this.debugLabel,
    this.affectedBoundsRef,
    this.metadataRef,
  });

  final BrushPaintCommandId id;
  final int sequenceNumber;
  final BrushPaintCommandKind kind;
  final BrushPaintCommandState state;
  final String? debugLabel;
  final String? affectedBoundsRef;
  final String? metadataRef;

  BrushPaintCommand copyWith({BrushPaintCommandState? state}) {
    return BrushPaintCommand(
      id: id,
      sequenceNumber: sequenceNumber,
      kind: kind,
      state: state ?? this.state,
      debugLabel: debugLabel,
      affectedBoundsRef: affectedBoundsRef,
      metadataRef: metadataRef,
    );
  }
}
