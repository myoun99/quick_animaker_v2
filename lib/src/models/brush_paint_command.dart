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
    this.materializationRef,
    this.metadataRef,
  });

  final BrushPaintCommandId id;
  final int sequenceNumber;
  final BrushPaintCommandKind kind;
  final BrushPaintCommandState state;
  final String? debugLabel;
  final String? affectedBoundsRef;

  /// Stable internal reference to the bitmap materialization payload that this
  /// command was created from.
  ///
  /// This is the minimal bridge from production-facing paint-command undo refs
  /// back to the current session-local bitmap materialization result. It is not
  /// a save/load payload format, durable command history, public undo entry, or
  /// bitmap/cache payload. The user-facing brush undo boundary remains:
  ///
  /// UndoPayloadRef.paintCommand -> BrushFrameStore -> BrushPaintCommand.
  final String? materializationRef;
  final String? metadataRef;

  BrushPaintCommand copyWith({BrushPaintCommandState? state}) {
    return BrushPaintCommand(
      id: id,
      sequenceNumber: sequenceNumber,
      kind: kind,
      state: state ?? this.state,
      debugLabel: debugLabel,
      affectedBoundsRef: affectedBoundsRef,
      materializationRef: materializationRef,
      metadataRef: metadataRef,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushPaintCommand &&
          other.id == id &&
          other.sequenceNumber == sequenceNumber &&
          other.kind == kind &&
          other.state == state &&
          other.debugLabel == debugLabel &&
          other.affectedBoundsRef == affectedBoundsRef &&
          other.materializationRef == materializationRef &&
          other.metadataRef == metadataRef;

  @override
  int get hashCode => Object.hash(
    id,
    sequenceNumber,
    kind,
    state,
    debugLabel,
    affectedBoundsRef,
    materializationRef,
    metadataRef,
  );

  @override
  String toString() =>
      'BrushPaintCommand(id: $id, sequenceNumber: $sequenceNumber, '
      'kind: $kind, state: $state, materializationRef: $materializationRef)';
}
