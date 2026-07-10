import 'dart:ui' as ui;

import '../../models/brush_frame_key.dart';
import '../../models/canvas_size.dart';
import '../../models/playback_quality.dart';
import '../../services/brush_frame_display_cache_renderer.dart';
import '../../services/brush_frame_display_cache_service.dart';
import '../../services/brush_frame_store.dart';
import '../canvas/bitmap_tile_image_cache.dart';
import '../canvas/deferred_image_disposal.dart';
import '../canvas/tiled_surface_compose.dart';
import 'playback_cache_budget.dart';

class _LayerFrameImageEntry {
  _LayerFrameImageEntry({
    required this.image,
    required this.sourceRevision,
    required this.canvasSize,
    required this.lastUsed,
  });

  final ui.Image image;
  final int sourceRevision;
  final CanvasSize canvasSize;
  int lastUsed;
}

/// Level-1 playback cache: one GPU [ui.Image] per (layer frame, quality),
/// built from the brush store's display-cache surface (the first production
/// consumer of [BrushFrameDisplayCacheService]).
///
/// Validity is revision-based: an entry is valid iff its stored
/// `sourceRevision` (and canvas size) still match the store's current
/// drawing state, so brush edits and undo/redo invalidate without any event
/// plumbing. [invalidateFrame] additionally drops entries eagerly on sink
/// events to free memory sooner.
class LayerFrameImageCache {
  LayerFrameImageCache({required this.frameStore});

  final BrushFrameStore frameStore;
  final Map<(BrushFrameKey, PlaybackQuality), _LayerFrameImageEntry> _entries =
      {};
  int _useCounter = 0;

  /// The cached image when it still matches the frame's current source
  /// revision and [canvasSize]; `null` on miss or staleness.
  ui.Image? validImageOrNull(
    BrushFrameKey key,
    PlaybackQuality quality, {
    required CanvasSize canvasSize,
  }) {
    final entry = _entries[(key, quality)];
    if (entry == null ||
        entry.canvasSize != canvasSize ||
        entry.sourceRevision != _currentRevision(key)) {
      return null;
    }
    entry.lastUsed = ++_useCounter;
    return entry.image;
  }

  /// Returns a valid image, rebuilding it when missing or stale. `null` when
  /// the frame has no drawn content.
  Future<ui.Image?> prepare({
    required BrushFrameKey key,
    required CanvasSize canvasSize,
    required PlaybackQuality quality,
  }) async {
    final cached = validImageOrNull(key, quality, canvasSize: canvasSize);
    if (cached != null) {
      return cached;
    }

    final drawing = frameStore.frameOrNull(key);
    if (drawing == null || drawing.allPaintCommandsInDisplayOrder.isEmpty) {
      _dropEntry((key, quality));
      return null;
    }
    final revision = drawing.sourceRevision;

    final preview = BrushFrameDisplayCacheService(
      frameStore: frameStore,
      renderer: BrushFrameDisplayCacheRenderer(canvasSize: canvasSize),
    ).prepareFramePreview(key).previewSurface;

    // Per-tile GPU compose: the editing canvas keeps the on-screen frame's
    // tiles decoded in the shared cache, so the post-stroke rebuild draws
    // existing tile images instead of assembling + uploading the whole
    // canvas — cost follows the CHANGED tiles, not the canvas size.
    var image = await composeTiledSurfaceImage(
      preview,
      reuse: BitmapTileImageCache.instance,
    );
    if (quality != PlaybackQuality.full) {
      final scaled = scaledCanvasSize(canvasSize, quality);
      final downscaled = await _downscale(image, scaled);
      image.dispose();
      image = downscaled;
    }

    _dropEntry((key, quality));
    _entries[(key, quality)] = _LayerFrameImageEntry(
      image: image,
      sourceRevision: revision,
      canvasSize: canvasSize,
      lastUsed: ++_useCounter,
    );
    return image;
  }

  /// Synchronous fast path for the editing canvas's layer-switch handoff:
  /// the valid cached image, or — full quality only — a sync compose from
  /// tiles already decoded in the shared tile cache (the just-deactivated
  /// on-screen frame's tiles always are). `null` means the caller must
  /// fall back to [prepare].
  ui.Image? prepareSyncOrNull({
    required BrushFrameKey key,
    required CanvasSize canvasSize,
    required PlaybackQuality quality,
  }) {
    final cached = validImageOrNull(key, quality, canvasSize: canvasSize);
    if (cached != null) {
      return cached;
    }
    if (quality != PlaybackQuality.full) {
      return null;
    }

    final drawing = frameStore.frameOrNull(key);
    if (drawing == null || drawing.allPaintCommandsInDisplayOrder.isEmpty) {
      return null;
    }
    final revision = drawing.sourceRevision;

    final preview = BrushFrameDisplayCacheService(
      frameStore: frameStore,
      renderer: BrushFrameDisplayCacheRenderer(canvasSize: canvasSize),
    ).prepareFramePreview(key).previewSurface;
    final image = composeTiledSurfaceImageSyncOrNull(
      preview,
      reuse: BitmapTileImageCache.instance,
    );
    if (image == null) {
      return null;
    }

    _dropEntry((key, quality));
    _entries[(key, quality)] = _LayerFrameImageEntry(
      image: image,
      sourceRevision: revision,
      canvasSize: canvasSize,
      lastUsed: ++_useCounter,
    );
    return image;
  }

  /// Eagerly drops every quality of one layer frame (sink-event eviction).
  void invalidateFrame(BrushFrameKey key) {
    for (final quality in PlaybackQuality.values) {
      _dropEntry((key, quality));
    }
  }

  int get estimatedBytes {
    var total = 0;
    for (final entry in _entries.values) {
      total += estimatedImageBytes(entry.image.width, entry.image.height);
    }
    return total;
  }

  /// Evicts least-recently-used entries until at or under [targetBytes].
  void evictLeastRecentlyUsed({required int targetBytes}) {
    final ordered = _entries.entries.toList()
      ..sort((a, b) => a.value.lastUsed.compareTo(b.value.lastUsed));
    var bytes = estimatedBytes;
    for (final entry in ordered) {
      if (bytes <= targetBytes) {
        break;
      }
      bytes -= estimatedImageBytes(
        entry.value.image.width,
        entry.value.image.height,
      );
      _dropEntry(entry.key);
    }
  }

  void dispose() {
    for (final key in _entries.keys.toList()) {
      _dropEntry(key);
    }
  }

  int _currentRevision(BrushFrameKey key) =>
      frameStore.frameOrNull(key)?.sourceRevision ?? 0;

  void _dropEntry((BrushFrameKey, PlaybackQuality) cacheKey) {
    final entry = _entries.remove(cacheKey);
    if (entry != null) {
      // Deferred, never direct: the image may still be referenced by the
      // frame currently on screen (same race the tile cache guards against).
      DeferredImageDisposer.instance.retire(entry.image);
    }
  }

  Future<ui.Image> _downscale(ui.Image source, CanvasSize target) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      source,
      ui.Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, target.width.toDouble(), target.height.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(target.width, target.height);
    } finally {
      picture.dispose();
    }
  }
}
