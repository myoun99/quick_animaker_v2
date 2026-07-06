import '../models/bitmap_surface.dart';
import '../models/brush_bitmap_materialization_history_state.dart';
import '../models/brush_edit_session_state.dart';
import '../models/brush_frame_key.dart';
import '../models/canvas_size.dart';
import '../models/canvas_surface_state.dart';

class BrushFrameEditSessionStore {
  BrushFrameEditSessionStore({
    required CanvasSize canvasSize,
    this.tileSize = 256,
  }) : _canvasSize = canvasSize;

  CanvasSize _canvasSize;
  final int tileSize;
  final Map<BrushFrameKey, BrushEditSessionState> _sessions = {};

  CanvasSize get canvasSize => _canvasSize;

  /// Adopts a new canvas size and drops every session state: session surfaces
  /// are derived caches at the old size, so the caller must rebuild them from
  /// the durable paint commands.
  void resizeCanvas(CanvasSize canvasSize) {
    if (canvasSize == _canvasSize) {
      return;
    }
    _canvasSize = canvasSize;
    _sessions.clear();
  }

  BrushEditSessionState getOrCreate(BrushFrameKey key) {
    return _sessions.putIfAbsent(key, _createBlankSessionState);
  }

  BrushEditSessionState? sessionOrNull(BrushFrameKey key) => _sessions[key];

  BrushEditSessionState update(
    BrushFrameKey key,
    BrushEditSessionState sessionState,
  ) {
    _sessions[key] = sessionState;
    return sessionState;
  }

  BrushEditSessionState reset(BrushFrameKey key) {
    final next = _createBlankSessionState();
    _sessions[key] = next;
    return next;
  }

  BrushEditSessionState _createBlankSessionState() {
    return BrushEditSessionState(
      canvasState: CanvasSurfaceState(
        currentSurface: BitmapSurface(
          canvasSize: _canvasSize,
          tileSize: tileSize,
        ),
      ),
      materializationHistoryState: BrushBitmapMaterializationHistoryState(),
    );
  }
}
