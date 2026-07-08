import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/brush_history_policy.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_display_cache_renderer.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_display_cache_service.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_edit_session_store.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_editing_coordinator.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';

/// Documents the post-stroke freeze fix (keep; prints the measured gap).
///
/// Before: every commit dirtied the display cache, and the next consumer
/// (playback prerender, storyboard thumbnail, camera preview) replayed the
/// frame's WHOLE command list on the UI thread — cost grows with every
/// stroke, so even a tiny stroke froze the app for the full-frame replay.
/// After: the commit donates the session surface, so the consumer's
/// prepare is a cache hit.
void main() {
  test('post-commit preview: donated-cache hit vs full command replay', () {
    const canvasSize = CanvasSize(width: 640, height: 360);
    final key = BrushFrameKey(
      projectId: const ProjectId('project'),
      trackId: const TrackId('track'),
      cutId: const CutId('cut'),
      layerId: const LayerId('layer'),
      frameId: const FrameId('frame'),
    );
    final store = BrushFrameStore();
    final coordinator = BrushFrameEditingCoordinator(
      initialFrameKey: key,
      frameStore: store,
      sessionStore: BrushFrameEditSessionStore(canvasSize: canvasSize),
      historyPolicy: const BrushHistoryPolicy(
        userUndoLimit: 64,
        deferredBakeRatio: 0,
      ),
    );

    // A realistic accumulated drawing: 40 strokes × 25 dabs.
    for (var stroke = 0; stroke < 40; stroke += 1) {
      coordinator.commitSourceStroke(
        sourceDabs: [
          for (var dab = 0; dab < 25; dab += 1)
            BrushDab(
              center: CanvasPoint(
                x: 20.0 + (stroke * 15) % 600 + dab * 0.8,
                y: 20.0 + (stroke * 8) % 320 + dab * 0.5,
              ),
              color: 0xFF000000 | (stroke * 6151),
              size: 16,
              opacity: 0.9,
              flow: 0.9,
              hardness: 0.8,
              tipShape: BrushTipShape.round,
              pressure: 1,
              sequence: dab,
            ),
        ],
      );
    }

    final frame = store.getOrCreateFrame(key);
    final replayWatch = Stopwatch()..start();
    const BrushFrameDisplayCacheRenderer(
      canvasSize: canvasSize,
    ).rebuildPreview(frame);
    replayWatch.stop();

    final hitWatch = Stopwatch()..start();
    final cache = BrushFrameDisplayCacheService(
      frameStore: store,
      renderer: const BrushFrameDisplayCacheRenderer(canvasSize: canvasSize),
    ).prepareFramePreview(key);
    hitWatch.stop();

    expect(cache.isValid, isTrue);
    expect(
      hitWatch.elapsedMicroseconds,
      lessThan(replayWatch.elapsedMicroseconds),
      reason: 'the donated cache must beat a full replay outright',
    );
    // ignore: avoid_print
    print(
      'post-commit preview @640x360, 40 strokes x 25 dabs — '
      'full replay: ${replayWatch.elapsedMilliseconds}ms, '
      'donated-cache hit: ${hitWatch.elapsedMicroseconds}us',
    );
  });
}
