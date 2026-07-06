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
import 'package:quick_animaker_v2/src/models/playback_quality.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_edit_session_store.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_editing_coordinator.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';
import 'package:quick_animaker_v2/src/ui/playback/layer_frame_image_cache.dart';

void main() {
  const canvasSize = CanvasSize(width: 8, height: 8);

  BrushFrameKey key(String frameId) => BrushFrameKey(
    projectId: const ProjectId('project'),
    trackId: const TrackId('track'),
    cutId: const CutId('cut'),
    layerId: const LayerId('layer'),
    frameId: FrameId(frameId),
  );

  BrushDab dab({double x = 1, double y = 1}) => BrushDab(
    center: CanvasPoint(x: x, y: y),
    color: 0xFF000000,
    size: 2,
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.round,
    pressure: 1,
    sequence: 0,
  );

  (BrushFrameStore, BrushFrameEditingCoordinator) storeWithStroke() {
    final store = BrushFrameStore();
    final coordinator = BrushFrameEditingCoordinator(
      initialFrameKey: key('frame-a'),
      frameStore: store,
      sessionStore: BrushFrameEditSessionStore(
        canvasSize: canvasSize,
        tileSize: 4,
      ),
      historyPolicy: const BrushHistoryPolicy(
        userUndoLimit: 8,
        deferredBakeRatio: 0,
      ),
    );
    coordinator.commitSourceStroke(sourceDabs: [dab()]);
    return (store, coordinator);
  }

  testWidgets('prepare renders at the quality raster size', (tester) async {
    await tester.runAsync(() async {
      final (store, _) = storeWithStroke();
      final cache = LayerFrameImageCache(frameStore: store);

      final full = await cache.prepare(
        key: key('frame-a'),
        canvasSize: canvasSize,
        quality: PlaybackQuality.full,
      );
      final quarter = await cache.prepare(
        key: key('frame-a'),
        canvasSize: canvasSize,
        quality: PlaybackQuality.quarter,
      );

      expect(full!.width, 8);
      expect(full.height, 8);
      expect(quarter!.width, 2);
      expect(quarter.height, 2);
      cache.dispose();
    });
  });

  testWidgets('second prepare is a cache hit returning the same image', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (store, _) = storeWithStroke();
      final cache = LayerFrameImageCache(frameStore: store);

      final first = await cache.prepare(
        key: key('frame-a'),
        canvasSize: canvasSize,
        quality: PlaybackQuality.half,
      );
      final second = await cache.prepare(
        key: key('frame-a'),
        canvasSize: canvasSize,
        quality: PlaybackQuality.half,
      );

      expect(identical(first, second), isTrue);
      expect(
        identical(
          cache.validImageOrNull(
            key('frame-a'),
            PlaybackQuality.half,
            canvasSize: canvasSize,
          ),
          first,
        ),
        isTrue,
      );
      cache.dispose();
    });
  });

  testWidgets('a new stroke commit invalidates via source revision', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (store, coordinator) = storeWithStroke();
      final cache = LayerFrameImageCache(frameStore: store);

      final first = await cache.prepare(
        key: key('frame-a'),
        canvasSize: canvasSize,
        quality: PlaybackQuality.full,
      );

      coordinator.commitSourceStroke(sourceDabs: [dab(x: 5, y: 5)]);

      expect(
        cache.validImageOrNull(
          key('frame-a'),
          PlaybackQuality.full,
          canvasSize: canvasSize,
        ),
        isNull,
      );
      final rebuilt = await cache.prepare(
        key: key('frame-a'),
        canvasSize: canvasSize,
        quality: PlaybackQuality.full,
      );
      expect(identical(first, rebuilt), isFalse);
      cache.dispose();
    });
  });

  testWidgets('undrawn frames yield null', (tester) async {
    await tester.runAsync(() async {
      final (store, _) = storeWithStroke();
      final cache = LayerFrameImageCache(frameStore: store);

      expect(
        await cache.prepare(
          key: key('frame-undrawn'),
          canvasSize: canvasSize,
          quality: PlaybackQuality.full,
        ),
        isNull,
      );
      cache.dispose();
    });
  });

  testWidgets('invalidateFrame drops all qualities', (tester) async {
    await tester.runAsync(() async {
      final (store, _) = storeWithStroke();
      final cache = LayerFrameImageCache(frameStore: store);
      await cache.prepare(
        key: key('frame-a'),
        canvasSize: canvasSize,
        quality: PlaybackQuality.full,
      );
      await cache.prepare(
        key: key('frame-a'),
        canvasSize: canvasSize,
        quality: PlaybackQuality.half,
      );
      expect(cache.estimatedBytes, greaterThan(0));

      cache.invalidateFrame(key('frame-a'));

      expect(cache.estimatedBytes, 0);
      cache.dispose();
    });
  });

  testWidgets('LRU eviction keeps the most recently used entries', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (store, coordinator) = storeWithStroke();
      coordinator.selectFrame(key('frame-b'));
      coordinator.commitSourceStroke(sourceDabs: [dab(x: 6, y: 6)]);
      final cache = LayerFrameImageCache(frameStore: store);

      await cache.prepare(
        key: key('frame-a'),
        canvasSize: canvasSize,
        quality: PlaybackQuality.full,
      );
      final recent = await cache.prepare(
        key: key('frame-b'),
        canvasSize: canvasSize,
        quality: PlaybackQuality.full,
      );

      // 8×8 RGBA = 256 bytes per image; keep room for exactly one.
      cache.evictLeastRecentlyUsed(targetBytes: 256);

      expect(
        cache.validImageOrNull(
          key('frame-a'),
          PlaybackQuality.full,
          canvasSize: canvasSize,
        ),
        isNull,
      );
      expect(
        identical(
          cache.validImageOrNull(
            key('frame-b'),
            PlaybackQuality.full,
            canvasSize: canvasSize,
          ),
          recent,
        ),
        isTrue,
      );
      cache.dispose();
    });
  });
}
