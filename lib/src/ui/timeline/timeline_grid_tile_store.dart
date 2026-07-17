import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../native/qa_native_engine.dart';
import 'timeline_frame_window.dart';
import 'timeline_grid_tile_ops.dart';
import 'timeline_row_cells_painter.dart';

/// The drawing rows' SUBSTRATE tile store (UI-R18 O7 T2, R18-T).
///
/// A row's cell substrate — the paper-block fills and their borders, the
/// dense mostly-static part of every repaint — rasterizes ONCE per
/// (row, span, look) through the native `qa_grid_raster_tile` and lands
/// here as a premultiplied [ui.Image]; the row painter then draws one
/// `drawImageRect` per span instead of 2-3 canvas calls per cell.
/// Foreground ink (glyphs, hold dashes, the sparse part) stays the
/// painter's Dart pass on top.
///
/// Contracts:
/// - Tiles are TRANSPARENT (background 0): accumulation from
///   transparent black is premultiplied, the raw-upload contract, so a
///   tile composites pixel-true over any panel background.
/// - The tile grid rides the SHARED window policy
///   ([timelineFrameWindowSpanFor]): tile i covers cells
///   [i*span, (i+1)*span) — scrolling reuses tiles bucket by bucket.
/// - Keys carry the full LOOK identity (layer object identity — layers
///   are immutable, an edit is a new instance — active flag, extents,
///   playback count, scheme, DPR): any mismatch re-rasters, so edits
///   invalidate exactly like `shouldRepaint`.
/// - NO native engine (flutter_tester, unsupported platforms, load
///   failure) = the store stands down entirely ([tileFor] returns null
///   and requests nothing): rows keep the classic Dart paint, tests and
///   packaging stay byte-for-byte on today's path.
class TimelineGridTileStore {
  TimelineGridTileStore._();

  static final TimelineGridTileStore instance = TimelineGridTileStore._();

  /// Bumped when a tile upload lands — the row painters merge this into
  /// their repaint listenable, so the landed tile paints on the next
  /// frame (cold spans show the classic paint meanwhile: no flash).
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// LRU cap. A span tile at 96px × a 28px row × DPR 2 ≈ 42KB; 768
  /// covers dozens of rows × the whole scroll neighborhood before
  /// eviction starts.
  static const int capacity = 768;

  final LinkedHashMap<String, _TileEntry> _entries =
      LinkedHashMap<String, _TileEntry>();
  final Map<String, _TileRequest> _pending = <String, _TileRequest>{};
  bool _drainScheduled = false;

  /// Test hook.
  @visibleForTesting
  void clear() {
    for (final entry in _entries.values) {
      entry.image.dispose();
    }
    _entries.clear();
    _pending.clear();
  }

  /// The fresh substrate tile for [painter]'s span starting at
  /// [spanStartIndex], or null (cold/stale — the classic paint covers
  /// this frame, and a raster is scheduled off the paint phase).
  ui.Image? tileFor({
    required TimelineRowCellsPainter painter,
    required int spanStartIndex,
    required int spanEndIndexExclusive,
    required double devicePixelRatio,
  }) {
    if (QaNativeEngine.instance == null) {
      return null;
    }
    final key =
        '${painter.layer.id.value}:${painter.axis.index}:$spanStartIndex';
    final entry = _entries.remove(key);
    if (entry != null) {
      _entries[key] = entry;
      if (entry.matches(painter, spanEndIndexExclusive, devicePixelRatio)) {
        return entry.image;
      }
    }
    // Cold or stale: schedule ONE raster per key (the newest look wins —
    // a stale in-flight request re-checks at drain time).
    _pending[key] = _TileRequest(
      painter: painter,
      spanStartIndex: spanStartIndex,
      spanEndIndexExclusive: spanEndIndexExclusive,
      devicePixelRatio: devicePixelRatio,
    );
    if (!_drainScheduled) {
      _drainScheduled = true;
      // Off the paint phase; microtasks run before the next frame, so a
      // tile can land within a frame or two.
      scheduleMicrotask(_drain);
    }
    return null;
  }

  Future<void> _drain() async {
    _drainScheduled = false;
    final engine = QaNativeEngine.instance;
    if (engine == null) {
      _pending.clear();
      return;
    }
    while (_pending.isNotEmpty) {
      final key = _pending.keys.first;
      final request = _pending.remove(key)!;
      final image = await _raster(engine, request);
      if (image == null) {
        continue;
      }
      _entries.remove(key)?.image.dispose();
      _entries[key] = _TileEntry(
        layer: request.painter.layer,
        active: request.painter.active,
        playbackFrameCount: request.painter.playbackFrameCount,
        frameCellExtent: request.painter.frameCellExtent,
        crossAxisExtent: request.painter.crossAxisExtent,
        colorScheme: request.painter.colorScheme,
        exposureStateForLayer: request.painter.exposureStateForLayer,
        spanEndIndexExclusive: request.spanEndIndexExclusive,
        devicePixelRatio: request.devicePixelRatio,
        image: image,
      );
      while (_entries.length > capacity) {
        _entries.remove(_entries.keys.first)!.image.dispose();
      }
      revision.value += 1;
    }
  }

  Future<ui.Image?> _raster(QaNativeEngine engine, _TileRequest request) async {
    final painter = request.painter;
    final dpr = request.devicePixelRatio;
    final spanCells = request.spanEndIndexExclusive - request.spanStartIndex;
    final width = (spanCells * painter.frameCellExtent * dpr).ceil();
    final height = (painter.crossAxisExtent * dpr).ceil();
    if (width <= 0 || height <= 0 || spanCells <= 0) {
      return null;
    }
    final horizontal = painter.axis == Axis.horizontal;
    final tileWidth = horizontal ? width : height;
    final tileHeight = horizontal ? height : width;

    final ops = timelineGridSubstrateOps(
      painter: painter,
      spanStartIndex: request.spanStartIndex,
      spanEndIndexExclusive: request.spanEndIndexExclusive,
      devicePixelRatio: dpr,
    );
    final pixels = Uint8List(tileWidth * tileHeight * 4);
    final result = engine.gridRasterTileBytes(
      pixels: pixels,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      backgroundRgba: 0,
      ops: ops,
    );
    if (result != 0) {
      assert(false, 'qa_grid_raster_tile failed: $result');
      return null;
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: tileWidth,
      height: tileHeight,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    return frame.image;
  }
}

class _TileRequest {
  const _TileRequest({
    required this.painter,
    required this.spanStartIndex,
    required this.spanEndIndexExclusive,
    required this.devicePixelRatio,
  });

  final TimelineRowCellsPainter painter;
  final int spanStartIndex;
  final int spanEndIndexExclusive;
  final double devicePixelRatio;
}

class _TileEntry {
  const _TileEntry({
    required this.layer,
    required this.active,
    required this.playbackFrameCount,
    required this.frameCellExtent,
    required this.crossAxisExtent,
    required this.colorScheme,
    required this.exposureStateForLayer,
    required this.spanEndIndexExclusive,
    required this.devicePixelRatio,
    required this.image,
  });

  final Object layer;
  final bool active;
  final int playbackFrameCount;
  final double frameCellExtent;
  final double crossAxisExtent;
  final Object colorScheme;
  final Object exposureStateForLayer;
  final int spanEndIndexExclusive;
  final double devicePixelRatio;
  final ui.Image image;

  /// The `shouldRepaint` identity, tile edition: any changed look fact
  /// re-rasters.
  bool matches(
    TimelineRowCellsPainter painter,
    int spanEndIndexExclusive,
    double devicePixelRatio,
  ) {
    return identical(layer, painter.layer) &&
        active == painter.active &&
        playbackFrameCount == painter.playbackFrameCount &&
        frameCellExtent == painter.frameCellExtent &&
        crossAxisExtent == painter.crossAxisExtent &&
        identical(colorScheme, painter.colorScheme) &&
        identical(exposureStateForLayer, painter.exposureStateForLayer) &&
        this.spanEndIndexExclusive == spanEndIndexExclusive &&
        this.devicePixelRatio == devicePixelRatio;
  }
}

/// Emits the SUBSTRATE op stream for [painter]'s cells in
/// [spanStartIndex, spanEndIndexExclusive): the background fill and the
/// block border per cell — geometry probed from the painter itself
/// ([TimelineRowCellsPainter.cellRectFor] / `resolvedCellStyleFor`), so
/// the tile look can never drift from the classic paint's. Coordinates
/// are tile-local physical pixels (row coords minus the span origin,
/// times DPR). Foreground ink (glyphs, dashes) stays the painter's Dart
/// pass.
Int32List timelineGridSubstrateOps({
  required TimelineRowCellsPainter painter,
  required int spanStartIndex,
  required int spanEndIndexExclusive,
  required double devicePixelRatio,
}) {
  final writer = TimelineGridTileOpWriter();
  final horizontal = painter.axis == Axis.horizontal;
  final originRect = painter.cellRectFor(spanStartIndex);
  final originMain = horizontal ? originRect.left : originRect.top;

  for (
    var frameIndex = spanStartIndex;
    frameIndex < spanEndIndexExclusive;
    frameIndex += 1
  ) {
    final style = painter.resolvedCellStyleFor(frameIndex);
    final background = style.background;
    final border = style.border;
    if (background.a <= 0 && border.a <= 0) {
      continue;
    }
    final rect = painter.cellRectFor(frameIndex);
    final local = horizontal
        ? rect.shift(Offset(-originMain, 0))
        : rect.shift(Offset(0, -originMain));

    // The radius map is uniform-6 per rounded corner (the painter's
    // _cellRadius): a corner MASK captures it exactly.
    final radius = style.radius;
    var mask = 0;
    var radiusValue = 0.0;
    if (radius != null) {
      if (radius.topLeft.x > 0) {
        mask |= TimelineGridTileOp.cornerTopLeft;
        radiusValue = radius.topLeft.x;
      }
      if (radius.topRight.x > 0) {
        mask |= TimelineGridTileOp.cornerTopRight;
        radiusValue = radius.topRight.x;
      }
      if (radius.bottomLeft.x > 0) {
        mask |= TimelineGridTileOp.cornerBottomLeft;
        radiusValue = radius.bottomLeft.x;
      }
      if (radius.bottomRight.x > 0) {
        mask |= TimelineGridTileOp.cornerBottomRight;
        radiusValue = radius.bottomRight.x;
      }
    }

    if (background.a > 0) {
      writer.rrectFill(
        local.left * devicePixelRatio,
        local.top * devicePixelRatio,
        local.width * devicePixelRatio,
        local.height * devicePixelRatio,
        radiusValue * devicePixelRatio,
        mask,
        timelineGridPackRgba(background),
      );
    }
    if (border.a > 0) {
      // Border.all paints INSIDE the box: stroke centered half a pixel
      // in (the painter's borderRect = rect.deflate(0.5), width 1).
      final borderRect = local.deflate(0.5);
      writer.rrectStroke(
        borderRect.left * devicePixelRatio,
        borderRect.top * devicePixelRatio,
        borderRect.width * devicePixelRatio,
        borderRect.height * devicePixelRatio,
        radiusValue * devicePixelRatio,
        mask,
        1.0 * devicePixelRatio,
        timelineGridPackRgba(border),
      );
    }
  }
  return writer.build();
}
