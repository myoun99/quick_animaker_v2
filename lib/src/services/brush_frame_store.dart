import '../models/brush_frame_drawing_state.dart';
import '../models/brush_frame_key.dart';
import '../models/brush_paint_command.dart';
import '../models/brush_paint_command_id.dart';
import '../models/brush_paint_command_state.dart';
import '../models/layer_id.dart';

class BrushFrameFlushResult {
  const BrushFrameFlushResult({required this.frameKey, required this.deferredCommands});

  final BrushFrameKey frameKey;
  final List<BrushPaintCommand> deferredCommands;
}

class BrushLayerFlushPlan {
  const BrushLayerFlushPlan({required this.layerId, required this.frames});

  final LayerId layerId;
  final List<BrushFrameFlushResult> frames;
}

class BrushFrameStore {
  BrushFrameStore();

  final Map<BrushFrameKey, BrushFrameDrawingState> _frames = {};

  BrushFrameDrawingState getOrCreateFrame(BrushFrameKey key) {
    return _frames.putIfAbsent(key, () => BrushFrameDrawingState(key: key));
  }

  BrushFrameDrawingState? frameOrNull(BrushFrameKey key) => _frames[key];

  BrushFrameDrawingState addLivePaintCommand(BrushFrameKey key, BrushPaintCommand command) {
    final live = command.copyWith(state: BrushPaintCommandState.live);
    return _update(key, (state) => state.copyWith(paintCommands: [...state.paintCommands, live]));
  }

  BrushFrameDrawingState markPaintCommandHiddenByUndo(BrushFrameKey key, BrushPaintCommandId id) {
    return _move(key, id, BrushPaintCommandState.hiddenByUndo);
  }

  BrushFrameDrawingState restorePaintCommandFromUndo(BrushFrameKey key, BrushPaintCommandId id) {
    return _move(key, id, BrushPaintCommandState.live);
  }

  BrushFrameDrawingState movePaintCommandToDeferredBake(BrushFrameKey key, BrushPaintCommandId id) {
    return _move(key, id, BrushPaintCommandState.deferredBake);
  }

  BrushFrameFlushResult flushFrame(BrushFrameKey key) {
    final state = getOrCreateFrame(key);
    return BrushFrameFlushResult(
      frameKey: key,
      deferredCommands: state.deferredBakePaintCommands,
    );
  }

  BrushFrameDrawingState markDeferredCommandsBaked(BrushFrameKey key) {
    return _update(key, (state) {
      final deferredIds = state.deferredBakePaintCommands.map((command) => command.id).toSet();
      final commands = state.paintCommands
          .map((command) => command.state == BrushPaintCommandState.deferredBake
              ? command.copyWith(state: BrushPaintCommandState.baked)
              : command)
          .toList();
      return state.copyWith(
        paintCommands: commands,
        bakedPaintCommandIds: {...state.bakedPaintCommandIds, ...deferredIds},
        inactivePreviewDirty: true,
      );
    });
  }

  BrushLayerFlushPlan flushLayer(LayerId layerId) {
    final frames = _frames.values
        .where((state) => state.key.layerId == layerId)
        .map((state) => flushFrame(state.key))
        .toList();
    return BrushLayerFlushPlan(layerId: layerId, frames: frames);
  }

  BrushFrameDrawingState _move(BrushFrameKey key, BrushPaintCommandId id, BrushPaintCommandState nextState) {
    return _update(key, (state) {
      final commands = state.paintCommands
          .map((command) => command.id == id ? command.copyWith(state: nextState) : command)
          .toList();
      return state.copyWith(paintCommands: commands);
    });
  }

  BrushFrameDrawingState _update(
    BrushFrameKey key,
    BrushFrameDrawingState Function(BrushFrameDrawingState state) update,
  ) {
    final next = update(getOrCreateFrame(key));
    _frames[key] = next;
    return next;
  }
}
