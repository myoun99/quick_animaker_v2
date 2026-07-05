import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
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

void main() {
  const canvasSize = CanvasSize(width: 16, height: 16);
  final key = BrushFrameKey(
    projectId: const ProjectId('project'),
    trackId: const TrackId('track'),
    cutId: const CutId('cut'),
    layerId: const LayerId('layer'),
    frameId: const FrameId('frame'),
  );

  BrushFrameEditingCoordinator coordinator() {
    return BrushFrameEditingCoordinator(
      initialFrameKey: key,
      frameStore: BrushFrameStore(),
      sessionStore: BrushFrameEditSessionStore(
        canvasSize: canvasSize,
        tileSize: 4,
      ),
      historyPolicy: const BrushHistoryPolicy(
        userUndoLimit: 8,
        deferredBakeRatio: 0,
      ),
    );
  }

  BrushFrameDisplayCacheService serviceFor(BrushFrameStore store) {
    return BrushFrameDisplayCacheService(
      frameStore: store,
      renderer: const BrushFrameDisplayCacheRenderer(
        canvasSize: canvasSize,
        tileSize: 4,
      ),
    );
  }

  test('display cache is derived', () {
    final c = coordinator();
    final command = c.commitSourceStroke(sourceDabs: [_dab(4, 4, 0)])!;

    final cache = serviceFor(c.frameStore).prepareFramePreview(key);
    final drawing = c.frameStore.getOrCreateFrame(key);

    expect(cache.isValid, isTrue);
    expect(cache.previewSurface.tiles, isNotEmpty);
    expect(drawing.commands, [command]);
    expect(drawing.commandById(command.id)!.sourceDabs, hasLength(1));
    expect(drawing.inactivePreviewDirty, isFalse);
  });

  test('commit undo redo dirty display cache', () {
    final c = coordinator();
    final service = serviceFor(c.frameStore);
    final command = c.commitSourceStroke(sourceDabs: [_dab(2, 2, 0)])!;
    service.prepareFramePreview(key);
    expect(c.frameStore.hasValidDisplayCache(key), isTrue);

    c.commitSourceStroke(sourceDabs: [_dab(8, 8, 1)]);
    expect(c.frameStore.displayCacheOrNull(key)!.dirty, isTrue);
    expect(c.frameStore.getOrCreateFrame(key).inactivePreviewDirty, isTrue);

    service.prepareFramePreview(key);
    c.undo();
    expect(c.frameStore.displayCacheOrNull(key)!.dirty, isTrue);
    expect(c.frameStore.getOrCreateFrame(key).hiddenCommandIds, isNotEmpty);

    service.prepareFramePreview(key);
    c.redo();
    expect(c.frameStore.displayCacheOrNull(key)!.dirty, isTrue);
    expect(c.frameStore.getOrCreateFrame(key).hiddenCommandIds, isEmpty);
    final restoredFrame = c.frameStore.getOrCreateFrame(key);
    expect(restoredFrame.commandById(command.id), command);
  });

  test('valid preview is reused', () {
    final c = coordinator();
    final service = serviceFor(c.frameStore);
    c.commitSourceStroke(sourceDabs: [_dab(3, 3, 0)]);

    final first = service.prepareFramePreview(key);
    final second = service.prepareFramePreview(key);

    expect(identical(first, second), isTrue);
    expect(c.frameStore.validPreviewSurfaceOrNull(key), first.previewSurface);
  });

  test('active overlay is not cached', () {
    final c = coordinator();
    c.commitSourceStroke(sourceDabs: [_dab(3, 3, 0)]);
    final cache = serviceFor(c.frameStore).prepareFramePreview(key);

    final activeOnlySurface = BrushFrameDisplayCacheRenderer(
      canvasSize: canvasSize,
      tileSize: 4,
    ).rebuildPreview(c.frameStore.getOrCreateFrame(key));

    expect(cache.previewSurface, activeOnlySurface);
    expect(cache.previewSurface, isA<BitmapSurface>());
    expect(c.frameStore.getOrCreateFrame(key).commands.single.sourceDabs, [
      _dab(3, 3, 0),
    ]);
  });

  test('live pointer path skips cache generation', () {
    final c = coordinator();

    c.activeSessionState;

    expect(c.frameStore.displayCacheOrNull(key), isNull);
  });
}

BrushDab _dab(double x, double y, int sequence) {
  return BrushDab(
    center: CanvasPoint(x: x, y: y),
    color: 0xFF000000,
    size: 2,
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.round,
    pressure: 1,
    sequence: sequence,
  );
}
