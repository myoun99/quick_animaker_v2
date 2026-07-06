import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/brush_history_policy.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/camera_pose.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_viewport.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/playback_quality.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_edit_session_store.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_editing_coordinator.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';
import 'package:quick_animaker_v2/src/ui/playback/canvas_playback_controller.dart';
import 'package:quick_animaker_v2/src/ui/playback/canvas_playback_view.dart';
import 'package:quick_animaker_v2/src/ui/playback/cut_frame_composite_cache.dart';
import 'package:quick_animaker_v2/src/ui/playback/layer_frame_image_cache.dart';
import 'package:quick_animaker_v2/src/ui/playback/playback_frame_painter.dart';
import 'package:quick_animaker_v2/src/ui/playback/playback_prerender_scheduler.dart';

void main() {
  const canvasSize = CanvasSize(width: 8, height: 8);

  BrushFrameKey frameKey(Cut cut, LayerId layerId, FrameId frameId) =>
      BrushFrameKey(
        projectId: const ProjectId('project'),
        trackId: const TrackId('track'),
        cutId: cut.id,
        layerId: layerId,
        frameId: frameId,
      );

  Cut cut() => Cut(
    id: const CutId('cut'),
    name: 'Cut',
    duration: 2,
    canvasSize: canvasSize,
    layers: [
      Layer(
        id: const LayerId('layer'),
        name: 'A',
        frames: [
          Frame(id: const FrameId('frame-a'), duration: 1, strokes: const []),
        ],
        timeline: {0: TimelineExposure.drawing(const FrameId('frame-a'))},
      ),
    ],
  );

  Project project() => Project(
    id: const ProjectId('project'),
    name: 'Project',
    fps: 10,
    cameraSize: const CanvasSize(width: 4, height: 2),
    tracks: [
      Track(id: const TrackId('track'), name: 'Track', cuts: [cut()]),
    ],
    createdAt: DateTime.utc(2026),
  );

  ({
    CutFrameCompositeCache composites,
    CanvasPlaybackController controller,
  })
  fixture() {
    final store = BrushFrameStore();
    BrushFrameEditingCoordinator(
      initialFrameKey: frameKey(
        cut(),
        const LayerId('layer'),
        const FrameId('frame-a'),
      ),
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
    final composites = CutFrameCompositeCache(
      layerImages: LayerFrameImageCache(frameStore: store),
      frameStore: store,
      frameKeyOf: frameKey,
    );
    final controller = CanvasPlaybackController(
      resolveProject: project,
      resolveActiveCutId: () => const CutId('cut'),
      resolveActiveTrackId: () => const TrackId('track'),
      resolveFps: () => 10,
    );
    return (composites: composites, controller: controller);
  }

  Future<void> pumpView(
    WidgetTester tester, {
    required CanvasPlaybackController controller,
    required CutFrameCompositeCache composites,
    bool cameraViewEnabled = false,
    ValueListenable<PrerenderProgress>? progress,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanvasPlaybackView(
            controller: controller,
            compositeCache: composites,
            qualityOf: () => PlaybackQuality.full,
            prerenderProgress:
                progress ?? ValueNotifier(PrerenderProgress.none),
            cameraViewEnabled: cameraViewEnabled,
            cameraFrameSize: const CanvasSize(width: 4, height: 2),
            cameraPoseOf: (cut, frameIndex) =>
                CameraPose(center: CanvasPoint(x: 4, y: 4)),
          ),
        ),
      ),
    );
  }

  PlaybackFramePainter painterOf(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('canvas-playback-view')),
        matching: find.byType(CustomPaint),
      ),
    );
    return paint.painter! as PlaybackFramePainter;
  }

  testWidgets('shows the warmed composite for the playback frame', (
    tester,
  ) async {
    final f = fixture();
    await tester.runAsync(() async {
      await f.composites.prepareComposite(
        cut: cut(),
        frameIndex: 0,
        quality: PlaybackQuality.full,
      );
      await f.composites.prepareComposite(
        cut: cut(),
        frameIndex: 1,
        quality: PlaybackQuality.full,
      );
    });

    f.controller.play(scope: PlaybackScope.activeCut);
    await pumpView(
      tester,
      controller: f.controller,
      composites: f.composites,
    );

    expect(painterOf(tester).image, isNotNull);
    expect(painterOf(tester).cameraPose, isNull);

    f.controller.stop();
    await tester.pump();
    f.composites.dispose();
  });

  testWidgets('camera view mode projects through the frame pose', (
    tester,
  ) async {
    final f = fixture();
    f.controller.play(scope: PlaybackScope.activeCut);
    await pumpView(
      tester,
      controller: f.controller,
      composites: f.composites,
      cameraViewEnabled: true,
    );

    expect(painterOf(tester).cameraPose, isNotNull);
    expect(
      painterOf(tester).cameraFrameSize,
      const CanvasSize(width: 4, height: 2),
    );

    f.controller.stop();
    await tester.pump();
    f.composites.dispose();
  });

  testWidgets('cache misses keep the last displayed frame on screen', (
    tester,
  ) async {
    final f = fixture();
    await tester.runAsync(() async {
      // Only frame 0 is warmed; frame 1 will miss.
      await f.composites.prepareComposite(
        cut: cut(),
        frameIndex: 0,
        quality: PlaybackQuality.full,
      );
    });

    f.controller.play(scope: PlaybackScope.activeCut);
    await pumpView(
      tester,
      controller: f.controller,
      composites: f.composites,
    );
    expect(painterOf(tester).image, isNotNull);

    // Advance to the uncached frame 1 (10fps → 100ms per frame).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(f.controller.position!.localFrameIndex, 1);
    expect(painterOf(tester).image, isNotNull, reason: 'stale frame held');

    f.controller.stop();
    await tester.pump();
    f.composites.dispose();
  });

  testWidgets('tapping the canvas cancels playback', (tester) async {
    final f = fixture();
    f.controller.play(scope: PlaybackScope.activeCut);
    await pumpView(
      tester,
      controller: f.controller,
      composites: f.composites,
    );
    expect(f.controller.isActive, isTrue);

    await tester.tap(
      find.byKey(const ValueKey<String>('canvas-playback-view')),
    );
    await tester.pump();

    expect(f.controller.isActive, isFalse);
    f.composites.dispose();
  });

  testWidgets('canvas mode paints under the panel viewport transform', (
    tester,
  ) async {
    final f = fixture();
    f.controller.play(scope: PlaybackScope.activeCut);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanvasPlaybackView(
            controller: f.controller,
            compositeCache: f.composites,
            qualityOf: () => PlaybackQuality.full,
            prerenderProgress: ValueNotifier(PrerenderProgress.none),
            cameraViewEnabled: false,
            cameraFrameSize: const CanvasSize(width: 4, height: 2),
            cameraPoseOf: (cut, frameIndex) =>
                CameraPose(center: CanvasPoint(x: 4, y: 4)),
            viewport: CanvasViewport(zoom: 2, panX: 10, panY: 20),
          ),
        ),
      ),
    );

    final painter = painterOf(tester);
    expect(painter.viewport, CanvasViewport(zoom: 2, panX: 10, panY: 20));
    expect(painter.cameraPose, isNull);

    f.controller.stop();
    await tester.pump();
    f.composites.dispose();
  });

  testWidgets('shows warming progress while the cache fills', (tester) async {
    final f = fixture();
    final progress = ValueNotifier(
      const PrerenderProgress(cached: 1, total: 4),
    );

    f.controller.play(scope: PlaybackScope.activeCut);
    await pumpView(
      tester,
      controller: f.controller,
      composites: f.composites,
      progress: progress,
    );

    expect(
      find.byKey(const ValueKey<String>('canvas-playback-progress')),
      findsOneWidget,
    );
    expect(find.text('caching 1/4'), findsOneWidget);

    progress.value = const PrerenderProgress(cached: 4, total: 4);
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('canvas-playback-progress')),
      findsNothing,
    );

    f.controller.stop();
    await tester.pump();
    f.composites.dispose();
  });
}
