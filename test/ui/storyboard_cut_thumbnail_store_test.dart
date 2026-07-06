import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_cache_invalidation.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/playback/editor_cache_invalidation_hub.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_cut_thumbnail_store.dart';

void main() {
  Future<ui.Image> tinyImage() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint());
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(2, 2);
    } finally {
      picture.dispose();
    }
  }

  Cut cut({bool layerVisible = true}) => Cut(
    id: const CutId('cut'),
    name: 'Cut',
    duration: 24,
    canvasSize: const CanvasSize(width: 8, height: 8),
    layers: [
      Layer(
        id: const LayerId('layer'),
        name: 'A',
        isVisible: layerVisible,
        frames: [Frame(id: const FrameId('f1'), duration: 1, strokes: const [])],
      ),
    ],
  );

  testWidgets('renders lazily, once per signature', (tester) async {
    var renderCount = 0;
    final store = StoryboardCutThumbnailStore(
      render: (_) {
        renderCount += 1;
        return tinyImage();
      },
    );
    addTearDown(store.dispose);
    var notified = 0;
    store.addListener(() => notified += 1);

    await tester.runAsync(() async {
      expect(store.thumbnailFor(cut()), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    expect(renderCount, 1);
    expect(notified, 1);
    expect(store.thumbnailFor(cut()), isNotNull);
    expect(renderCount, 1, reason: 'unchanged signature must not re-render');
  });

  testWidgets('layer visibility change re-renders', (tester) async {
    var renderCount = 0;
    final store = StoryboardCutThumbnailStore(
      render: (_) {
        renderCount += 1;
        return tinyImage();
      },
    );
    addTearDown(store.dispose);

    await tester.runAsync(() async {
      store.thumbnailFor(cut());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      store.thumbnailFor(cut(layerVisible: false));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    // The retired first image disposes on the next frame.
    await tester.pump();

    expect(renderCount, 2);
  });

  testWidgets('hub brush-frame events invalidate the cut', (tester) async {
    var renderCount = 0;
    final hub = EditorCacheInvalidationHub();
    final store = StoryboardCutThumbnailStore(
      render: (_) {
        renderCount += 1;
        return tinyImage();
      },
      invalidationHub: hub,
    );
    addTearDown(store.dispose);

    await tester.runAsync(() async {
      store.thumbnailFor(cut());
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    expect(renderCount, 1);

    hub.invalidateBrushFrame(
      BrushFrameCacheInvalidation.wholeFrame(
        const BrushFrameKey(
          projectId: ProjectId('project'),
          trackId: TrackId('track'),
          cutId: CutId('cut'),
          layerId: LayerId('layer'),
          frameId: FrameId('f1'),
        ),
      ),
    );

    await tester.runAsync(() async {
      store.thumbnailFor(cut());
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(renderCount, 2);
  });

  testWidgets('a null render result is cached, not retried per build', (
    tester,
  ) async {
    var renderCount = 0;
    final store = StoryboardCutThumbnailStore(
      render: (_) async {
        renderCount += 1;
        return null;
      },
    );
    addTearDown(store.dispose);

    await tester.runAsync(() async {
      store.thumbnailFor(cut());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(store.thumbnailFor(cut()), isNull);
    });

    expect(renderCount, 1);
  });
}
