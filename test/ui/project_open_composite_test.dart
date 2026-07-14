import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/brush_history_policy.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/playback_quality.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_display_cache_renderer.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_display_cache_service.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_edit_session_store.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_editing_coordinator.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/export/export_frame_renderer.dart';
import 'package:quick_animaker_v2/src/ui/export/export_plan.dart';
import 'package:quick_animaker_v2/src/ui/playback/layer_frame_image_cache.dart';

/// R19 P3a regression pins: a bake-only OPEN carries no paint commands —
/// the cel's picture is its baked raster — so every composite consumer
/// whose emptiness oracle was "commands.isEmpty" treated loaded cels as
/// BLANK (playback layer images, exports, fill compose / eyedropper).
void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qap-open-composite');
  });

  tearDown(() => directory.delete(recursive: true));

  /// A session with one committed stroke, saved and reopened — the state
  /// every consumer below must see CONTENT in.
  Future<(EditorSessionManager, BrushFrameKey)> reopenedSession() async {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    s.createDrawingAtCurrentFrame();
    final selection = s.activeBrushEditorSelection!;
    final drawnKey = s.brushFrameKeyForCut(
      s.activeCut,
      selection.layerId,
      selection.frameId,
    );
    BrushFrameEditingCoordinator(
      initialFrameKey: drawnKey,
      frameStore: s.brushFrameStore,
      sessionStore: BrushFrameEditSessionStore(
        canvasSize: s.activeCut.canvasSize,
        tileSize: 256,
      ),
      historyPolicy: const BrushHistoryPolicy(
        userUndoLimit: 8,
        deferredBakeRatio: 0,
      ),
    ).commitSourceStroke(
      sourceDabs: [
        BrushDab(
          center: CanvasPoint(x: 10, y: 10),
          color: 0xFF000000,
          size: 8,
          opacity: 1,
          flow: 1,
          hardness: 1,
          tipShape: BrushTipShape.round,
          pressure: 1,
          sequence: 0,
        ),
      ],
    );
    final path = '${directory.path}/scene.qap';
    await s.saveProjectToFile(path);
    await s.openProjectFromFile(path);
    // Sanity: the open really is command-free with baked truth.
    expect(
      s.brushFrameStore.frameOrNull(drawnKey)?.paintCommands ?? const [],
      isEmpty,
      reason: 'bake-only opens carry no commands',
    );
    expect(s.brushFrameStore.bakedSurfaceOrNull(drawnKey)?.tiles, isNotEmpty);
    return (s, drawnKey);
  }

  test('fill compose / eyedropper resolver serves the baked raster after '
      'an open (brushSurfaceForLayerFrame)', () async {
    final (s, drawnKey) = await reopenedSession();
    addTearDown(s.dispose);
    final layer = s.activeCut.layers.firstWhere(
      (layer) => layer.id == drawnKey.layerId,
    );
    final frame = Frame(id: drawnKey.frameId, duration: 1, strokes: const []);

    final surface = s.brushSurfaceForLayerFrame(layer, frame);

    expect(surface, isNotNull, reason: 'a loaded cel is NOT empty');
    expect(surface!.tiles, isNotEmpty);
    expect(
      identical(surface, s.brushFrameStore.bakedSurfaceOrNull(drawnKey)),
      isTrue,
      reason: 'served from the baked truth, no replay and no copy',
    );
  });

  testWidgets('playback layer images build from the baked raster after an '
      'open (LayerFrameImageCache)', (tester) async {
    await tester.runAsync(() async {
      final (s, drawnKey) = await reopenedSession();
      addTearDown(s.dispose);

      final cache = LayerFrameImageCache(frameStore: s.brushFrameStore);
      addTearDown(cache.dispose);
      final image = await cache.prepare(
        key: drawnKey,
        canvasSize: s.activeCut.canvasSize,
        quality: PlaybackQuality.full,
      );

      expect(image, isNotNull, reason: 'a loaded cel must render in playback');
    });
  });

  testWidgets('cel export renders the baked raster after an open '
      '(ExportFrameRenderer)', (tester) async {
    await tester.runAsync(() async {
      final (s, drawnKey) = await reopenedSession();
      addTearDown(s.dispose);
      final cut = s.activeCut;
      final layer = cut.layers.firstWhere(
        (layer) => layer.id == drawnKey.layerId,
      );
      final frame = Frame(id: drawnKey.frameId, duration: 1, strokes: const []);

      final image = await ExportFrameRenderer(session: s).renderCel(
        ExportCelTask(cut: cut, layer: layer, frame: frame, fileName: 'c.png'),
      );

      expect(image, isNotNull, reason: 'a loaded cel must export');
      final bytes = await image!.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      var hasInk = false;
      for (var i = 3; i < bytes!.lengthInBytes; i += 4) {
        if (bytes.getUint8(i) != 0) {
          hasInk = true;
          break;
        }
      }
      expect(hasInk, isTrue, reason: 'the exported cel is not blank');
    });
  });

  test('the display-cache service reseeds from the baked truth instead of '
      'replaying a command-free cel to BLANK', () {
    final store = BrushFrameStore();
    final canvasSize = CanvasSize(width: 512, height: 512);
    final key = BrushFrameKey(
      projectId: ProjectId('p'),
      trackId: TrackId('t'),
      cutId: CutId('c'),
      layerId: LayerId('l'),
      frameId: FrameId('f'),
    );
    final baked = materializeSingleDabSurface(canvasSize);
    store.restoreBaked({key: baked});
    // The cache is present after a restore; drop it to simulate any
    // invalidation and force the service down its rebuild path.
    store.clearDisplayCaches();

    final cache = BrushFrameDisplayCacheService(
      frameStore: store,
      renderer: BrushFrameDisplayCacheRenderer(canvasSize: canvasSize),
    ).prepareFramePreview(key);

    expect(
      identical(cache.previewSurface, store.bakedSurfaceOrNull(key)),
      isTrue,
      reason: 'baked served directly — a command replay would be blank',
    );
  });
}

/// One black dab materialized onto a blank surface (store-level fixture).
BitmapSurface materializeSingleDabSurface(CanvasSize canvasSize) {
  final store = BrushFrameStore();
  final sessionStore = BrushFrameEditSessionStore(
    canvasSize: canvasSize,
    tileSize: 256,
  );
  final key = BrushFrameKey(
    projectId: ProjectId('fixture'),
    trackId: TrackId('t'),
    cutId: CutId('c'),
    layerId: LayerId('l'),
    frameId: FrameId('f'),
  );
  BrushFrameEditingCoordinator(
    initialFrameKey: key,
    frameStore: store,
    sessionStore: sessionStore,
    historyPolicy: const BrushHistoryPolicy(
      userUndoLimit: 4,
      deferredBakeRatio: 0,
    ),
  ).commitSourceStroke(
    sourceDabs: [
      BrushDab(
        center: CanvasPoint(x: 20, y: 20),
        color: 0xFF000000,
        size: 8,
        opacity: 1,
        flow: 1,
        hardness: 1,
        tipShape: BrushTipShape.round,
        pressure: 1,
        sequence: 0,
      ),
    ],
  );
  return store.bakedSurfaceOrNull(key)!;
}
