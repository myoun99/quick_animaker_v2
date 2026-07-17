import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_coverage.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/native/qa_native_engine.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_tile_ops.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_tile_store.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_row_cells_painter.dart';

/// UI-R18 O7 T2: the substrate tile store — engine-gated stand-down,
/// probe-driven op emission, tile landing + look-identity invalidation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dllPath =
      '${Directory.current.path}\\build\\native_standalone\\Release\\qa_engine.dll';
  final available = File(dllPath).existsSync();

  TimelineCellExposureState stateFor(Layer layer, int frameIndex) {
    if (layer.timeline[frameIndex]?.isDrawing ?? false) {
      return TimelineCellExposureState.drawingStart;
    }
    if (coveringDrawingBlockAt(layer.timeline, frameIndex) != null) {
      return TimelineCellExposureState.held;
    }
    return TimelineCellExposureState.uncovered;
  }

  Layer blockLayer() => Layer(
    id: const LayerId('layer-a'),
    name: 'A',
    frames: [Frame(id: const FrameId('f1'), duration: 1, strokes: const [])],
    timeline: {0: const TimelineExposure.drawing(FrameId('f1'), length: 2)},
  );

  TimelineRowCellsPainter painterFor(
    Layer layer, {
    bool active = false,
    TimelineGridTileStore? store,
  }) {
    return TimelineRowCellsPainter(
      layer: layer,
      active: active,
      playbackFrameCount: 24,
      frameStartIndex: 0,
      frameEndIndexExclusive: 40,
      leadingFrameSpacerWidth: 0,
      frameCellExtent: 24,
      crossAxisExtent: 28,
      exposureStateForLayer: stateFor,
      colorScheme: const ColorScheme.dark(),
      baseTextStyle: const TextStyle(fontSize: 11),
      tileStore: store,
    );
  }

  setUp(() {
    QaNativeEngine.debugResetForTests();
    QaNativeEngine.debugLibraryPathOverride = dllPath;
    QaNativeEngine.debugForceDartFallback = false;
    TimelineGridTileStore.instance.clear();
  });

  tearDown(() {
    QaNativeEngine.debugResetForTests();
    QaNativeEngine.debugLibraryPathOverride = null;
    QaNativeEngine.debugForceDartFallback = false;
    TimelineGridTileStore.instance.clear();
  });

  test('WITHOUT the native engine the store stands down entirely — the '
      'classic paint path stays byte-for-byte (the suite-wide default)', () {
    QaNativeEngine.debugForceDartFallback = true;
    final store = TimelineGridTileStore.instance;
    final revisionBefore = store.revision.value;

    final image = store.tileFor(
      painter: painterFor(blockLayer()),
      spanStartIndex: 0,
      spanEndIndexExclusive: 4,
      devicePixelRatio: 1.0,
    );

    expect(image, isNull);
    expect(store.revision.value, revisionBefore);
  });

  test('the emitter probes the painter: the covered span opens with the '
      'block fill and its border, the empty span emits nothing', () {
    final painter = painterFor(blockLayer());
    final covered = timelineGridSubstrateOps(
      painter: painter,
      spanStartIndex: 0,
      spanEndIndexExclusive: 4,
      devicePixelRatio: 1.0,
    );
    expect(covered, isNotEmpty);
    expect(covered[0], TimelineGridTileOp.rrectFill);
    // The block START cell rounds its LEFT corners only (the painter's
    // radius map, mask TL|BL = 5).
    expect(covered[6], 5, reason: 'corner mask');
    expect(covered[5], timelineGridQ8(6), reason: 'radius 6 in q8');

    // Uncovered cells still fill their (flat, borderless) background —
    // exactly what the classic painter draws: 4 cells × one 8-word
    // square rrectFill, no strokes.
    final empty = timelineGridSubstrateOps(
      painter: painter,
      spanStartIndex: 8,
      spanEndIndexExclusive: 12,
      devicePixelRatio: 1.0,
    );
    expect(empty.length, 4 * 8);
    for (var cell = 0; cell < 4; cell += 1) {
      expect(empty[cell * 8], TimelineGridTileOp.rrectFill);
      expect(empty[cell * 8 + 6], 0, reason: 'no rounded corners');
    }
  });

  test('a cold span rasters off-frame, lands as a physical-resolution '
      'image, and a changed LOOK invalidates it', () async {
    if (!available) {
      markTestSkipped('qa_engine.dll not built');
      return;
    }
    final store = TimelineGridTileStore.instance;
    final layer = blockLayer();
    final painter = painterFor(layer, store: store);

    var landings = 0;
    store.revision.addListener(() => landings += 1);

    // Cold: null now, raster scheduled.
    expect(
      store.tileFor(
        painter: painter,
        spanStartIndex: 0,
        spanEndIndexExclusive: 4,
        devicePixelRatio: 2.0,
      ),
      isNull,
    );
    while (landings == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    final image = store.tileFor(
      painter: painter,
      spanStartIndex: 0,
      spanEndIndexExclusive: 4,
      devicePixelRatio: 2.0,
    );
    expect(image, isNotNull);
    expect(image!.width, 4 * 24 * 2, reason: 'span cells × extent × DPR');
    expect(image.height, 28 * 2);

    // The SAME look stays a hit (no new landing).
    final hits = landings;
    store.tileFor(
      painter: painter,
      spanStartIndex: 0,
      spanEndIndexExclusive: 4,
      devicePixelRatio: 2.0,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(landings, hits);

    // A changed look (active row) is STALE: miss now, fresh tile lands.
    final activePainter = painterFor(layer, active: true, store: store);
    expect(
      store.tileFor(
        painter: activePainter,
        spanStartIndex: 0,
        spanEndIndexExclusive: 4,
        devicePixelRatio: 2.0,
      ),
      isNull,
    );
    while (landings == hits) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      store.tileFor(
        painter: activePainter,
        spanStartIndex: 0,
        spanEndIndexExclusive: 4,
        devicePixelRatio: 2.0,
      ),
      isNotNull,
    );
  });
}
