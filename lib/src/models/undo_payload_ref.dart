import 'brush_frame_key.dart';
import 'brush_paint_command_id.dart';

class UndoPayloadRef {
  const UndoPayloadRef({
    required this.storeName,
    required this.payloadId,
    this.targetKey,
    this.targetPath,
  });

  factory UndoPayloadRef.paintCommand({
    required BrushFrameKey frameKey,
    required BrushPaintCommandId paintCommandId,
  }) {
    return UndoPayloadRef(
      storeName: paintStoreName,
      payloadId: paintCommandId.value,
      targetKey: frameKey,
    );
  }

  static const paintStoreName = 'brushFrameStore.paintCommand';

  final String storeName;
  final String payloadId;
  final BrushFrameKey? targetKey;
  final String? targetPath;

  bool get isPaintCommand =>
      storeName == paintStoreName && targetKey != null;

  BrushPaintCommandId get paintCommandId => BrushPaintCommandId(payloadId);
}
