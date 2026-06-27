import '../models/bitmap_surface.dart';
import '../models/brush_edit_history_state.dart';
import '../models/brush_edit_session_state.dart';
import '../models/brush_frame_key.dart';
import '../models/canvas_size.dart';
import '../models/canvas_surface_state.dart';

class BrushFrameEditSessionStore {
  BrushFrameEditSessionStore({required this.canvasSize, this.tileSize = 256});

  final CanvasSize canvasSize;
  final int tileSize;
  final Map<BrushFrameKey, BrushEditSessionState> _sessions = {};

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
        currentSurface: BitmapSurface(canvasSize: canvasSize, tileSize: tileSize),
      ),
      historyState: BrushEditHistoryState(),
    );
  }
}
