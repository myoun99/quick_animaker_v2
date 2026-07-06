import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/brush_history_policy.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_viewport.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_edit_session_store.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_editing_coordinator.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';
import 'package:quick_animaker_v2/src/ui/canvas/canvas_layer_stack_view.dart';
import 'package:quick_animaker_v2/src/ui/playback/layer_frame_image_cache.dart';

void main() {
  const canvasSize = CanvasSize(width: 8, height: 8);

  BrushFrameKey key(String layerId) => BrushFrameKey(
    projectId: const ProjectId('project'),
    trackId: const TrackId('track'),
    cutId: const CutId('cut'),
    layerId: LayerId(layerId),
    frameId: const FrameId('frame'),
  );

  LayerFrameImageCache cacheWithStroke() {
    final store = BrushFrameStore();
    BrushFrameEditingCoordinator(
      initialFrameKey: key('layer-below'),
      frameStore: store,
      sessionStore: BrushFrameEditSessionStore(
        canvasSize: canvasSize,
        tileSize: 4,
      ),
      historyPolicy: const BrushHistoryPolicy(
        userUndoLimit: 8,
        deferredBakeRatio: 0,
      ),
    ).commitSourceStroke(
      sourceDabs: [
        BrushDab(
          center: CanvasPoint(x: 1, y: 1),
          color: 0xFF000000,
          size: 2,
          opacity: 1,
          flow: 1,
          hardness: 1,
          tipShape: BrushTipShape.round,
          pressure: 1,
          sequence: 0,
        ),
      ],
    );
    return LayerFrameImageCache(frameStore: store);
  }

  testWidgets('paints drawn layers and skips undrawn ones', (tester) async {
    final cache = cacheWithStroke();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanvasLayerStackView(
            layers: [
              CanvasLayerImageRequest(frameKey: key('layer-below'), opacity: 0.5),
              CanvasLayerImageRequest(frameKey: key('layer-undrawn'), opacity: 1),
            ],
            imageCache: cache,
            canvasSize: canvasSize,
            viewport: CanvasViewport(zoom: 2),
            paintPaper: true,
          ),
        ),
      ),
    );
    // Let the async image preparation finish.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    // Paint-only (input passes through) and it renders without errors; the
    // undrawn layer resolves to nothing.
    expect(find.byType(IgnorePointer), findsWidgets);
    expect(tester.takeException(), isNull);
    cache.dispose();
  });
}
