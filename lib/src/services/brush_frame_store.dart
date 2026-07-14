import '../models/bitmap_surface.dart';
import '../models/canvas_size.dart';
import '../models/brush_frame_display_cache.dart';
import '../models/brush_frame_drawing_state.dart';
import '../models/brush_frame_key.dart';
import '../models/cut_id.dart';
import '../models/dirty_tile_set.dart';
import 'bitmap_surface_geometry.dart';

class BrushFrameStore {
  BrushFrameStore();

  final Map<BrushFrameKey, BrushFrameDrawingState> _frames = {};

  /// Derived preview caches. NOT byte-budgeted (R19 P3a): every donated or
  /// baked-seeded entry ALIASES the cel's [_bakedSurfaces] truth (the same
  /// immutable surface object), so evicting one freed nothing — the old
  /// budget/LRU/protected-cut machinery (R13/R16-⑤) only ever caused
  /// rebuild storms. Replay-built entries (legacy this-session command
  /// cels) are superseded by donations on the next edit.
  final Map<BrushFrameKey, BrushFrameDisplayCache> _displayCaches = {};

  BrushFrameDrawingState getOrCreateFrame(BrushFrameKey key) {
    return _frames.putIfAbsent(key, () => BrushFrameDrawingState(key: key));
  }

  BrushFrameDrawingState? frameOrNull(BrushFrameKey key) => _frames[key];

  BrushFrameDisplayCache? displayCacheOrNull(BrushFrameKey key) =>
      _displayCaches[key];

  bool hasValidDisplayCache(BrushFrameKey key) =>
      displayCacheOrNull(key)?.isValid ?? false;

  BitmapSurface? validPreviewSurfaceOrNull(BrushFrameKey key) {
    final cache = displayCacheOrNull(key);
    return cache != null && cache.isValid ? cache.previewSurface : null;
  }

  void _putDisplayCache(BrushFrameKey key, BrushFrameDisplayCache cache) {
    _displayCaches[key] = cache;
  }

  /// Drops every derived display cache, e.g. after a canvas resize makes the
  /// cached preview surfaces the wrong size. Source paint commands are kept.
  void clearDisplayCaches() {
    _displayCaches.clear();
  }

  // -------------------------------------------------------------------
  // Baked raster truth (R19 bake-only).
  //
  // From format v2 on, a cel's picture IS its baked tile raster — like
  // every raster program, what you saved is what reopens, byte for byte.
  // The map is deliberately NOT byte-budgeted: truth cannot be evicted
  // (the display-cache LRU above remains a derived-preview affair).
  // Surfaces are immutable and shared with sessions/donations, so this
  // adds no copies.

  final Map<BrushFrameKey, BitmapSurface> _bakedSurfaces = {};

  /// The cel's baked raster truth, or null for a never-drawn cel.
  BitmapSurface? bakedSurfaceOrNull(BrushFrameKey key) => _bakedSurfaces[key];

  /// Stores [surface] as the cel's baked truth (commit donations and
  /// project opens both land here).
  void storeBakedSurface(BrushFrameKey key, BitmapSurface surface) {
    if (surface.tiles.isEmpty) {
      _bakedSurfaces.remove(key);
      return;
    }
    _bakedSurfaces[key] = surface;
  }

  /// Every baked cel for the .qap v2 save payload — a reference-cheap map
  /// copy: the baked truth is ALWAYS current (every commit and snapshot
  /// restore donates into it), so the save payload is simply the truth.
  Map<BrushFrameKey, BitmapSurface> bakedSnapshotForSave() {
    return {..._bakedSurfaces};
  }

  /// Replaces the WHOLE store with loaded baked cels (v2 project open):
  /// frames reseed live at sourceRevision 1 with EMPTY command lists —
  /// the raster is the truth — and the display caches seed from the same
  /// surfaces so first paint is O(1).
  void restoreBaked(Map<BrushFrameKey, BitmapSurface> cels) {
    _frames.clear();
    clearDisplayCaches();
    _bakedSurfaces.clear();
    for (final entry in cels.entries) {
      _frames[entry.key] = BrushFrameDrawingState(
        key: entry.key,
        sourceRevision: 1,
      );
      _bakedSurfaces[entry.key] = entry.value;
      storeRebuiltDisplayCache(key: entry.key, previewSurface: entry.value);
    }
  }

  /// Whether the cel shows ANY picture content — the composite/export/
  /// fill resolvers' emptiness oracle. R19 P3b: the baked raster IS the
  /// content (commands retired; donations keep it current through every
  /// commit, undo and redo).
  bool celHasRenderableContent(BrushFrameKey key) =>
      _bakedSurfaces.containsKey(key);

  /// The cel's current pixels: a VALID display cache at [canvasSize]
  /// first (donations keep it fresh), else the baked truth. Null = the
  /// cel is empty (or sized for another canvas — resize flows reseed).
  BitmapSurface? currentSurfaceWithoutReplay(
    BrushFrameKey key, {
    required CanvasSize canvasSize,
  }) {
    final cached = validPreviewSurfaceOrNull(key);
    if (cached != null && cached.canvasSize == canvasSize) {
      return cached;
    }
    final baked = _bakedSurfaces[key];
    if (baked != null && baked.canvasSize == canvasSize) {
      return baked;
    }
    return null;
  }

  /// Re-homes stored drawings under new keys (a cross-layer block move,
  /// R10-④b): content is untouched, so the display cache travels along and
  /// stays valid. Missing sources are skipped (an empty cel moved). The
  /// inverse pair list undoes the move exactly.
  void rekeyFrames(List<(BrushFrameKey from, BrushFrameKey to)> pairs) {
    for (final (from, to) in pairs) {
      final state = _frames.remove(from);
      if (state != null) {
        _frames[to] = state.copyWithKey(to);
      }
      final cache = _displayCaches.remove(from);
      if (cache != null) {
        _displayCaches[to] = cache;
      }
      // The baked truth travels with the cel (R19).
      final baked = _bakedSurfaces.remove(from);
      if (baked != null) {
        _bakedSurfaces[to] = baked;
      }
    }
  }

  /// Shifts every cel of [cutId] by ([dx], [dy]) in canvas space, for
  /// canvas resizes anchored anywhere but the top-left corner. R19: a
  /// raster blit of the baked truth (anchors produce whole-pixel offsets;
  /// the resize command's reference snapshot covers the exact undo).
  void translateCutContent({
    required CutId cutId,
    required double dx,
    required double dy,
  }) {
    if (dx == 0 && dy == 0) {
      return;
    }
    for (final key in _bakedSurfaces.keys.toList()) {
      if (key.cutId != cutId) {
        continue;
      }
      _bakedSurfaces[key] = translateBitmapSurface(
        _bakedSurfaces[key]!,
        dx: dx.round(),
        dy: dy.round(),
        canvasSize: _bakedSurfaces[key]!.canvasSize,
      );
      markCelEdited(key);
    }
  }

  /// Adopts a new canvas size for every baked surface (R19: a resize is
  /// a raster crop/extend — top-left anchored, every tile kept, so
  /// shrinking then growing back restores exactly).
  void resizeBakedSurfaces(CanvasSize canvasSize) {
    for (final key in _bakedSurfaces.keys.toList()) {
      _bakedSurfaces[key] = resizeBitmapSurfaceCanvas(
        _bakedSurfaces[key]!,
        canvasSize,
      );
    }
  }

  /// The cut's baked surfaces by key — surfaces are immutable, so this
  /// snapshot is reference-cheap (the anchored-resize command keeps one
  /// for its exact undo).
  Map<BrushFrameKey, BitmapSurface> bakedSurfacesForCut(CutId cutId) {
    return {
      for (final entry in _bakedSurfaces.entries)
        if (entry.key.cutId == cutId) entry.key: entry.value,
    };
  }

  /// Restores a [bakedSurfacesForCut] snapshot (anchored-resize undo):
  /// the cut's baked set becomes exactly the snapshot again.
  void restoreBakedForCut(
    CutId cutId,
    Map<BrushFrameKey, BitmapSurface> snapshot,
  ) {
    _bakedSurfaces.removeWhere((key, _) => key.cutId == cutId);
    _bakedSurfaces.addAll(snapshot);
    for (final key in snapshot.keys) {
      // The display caches follow the restored truth.
      storeRebuiltDisplayCache(key: key, previewSurface: snapshot[key]!);
    }
  }

  BrushFrameDisplayCache storeRebuiltDisplayCache({
    required BrushFrameKey key,
    required BitmapSurface previewSurface,
  }) {
    final state = getOrCreateFrame(key);
    final cache = BrushFrameDisplayCache(
      frameKey: key,
      previewSurface: previewSurface,
      sourceRevision: state.sourceRevision,
      dirty: false,
    );
    _putDisplayCache(key, cache);
    _frames[key] = state.copyWith(
      inactivePreviewDirty: false,
      cacheDirtyTiles: DirtyTileSet.empty(),
    );
    return cache;
  }

  /// Records a pixel edit on the cel (R19 P3b — commands retired, this
  /// is the ONLY mutation signal): bumps the source revision so playback
  /// image caches invalidate, and dirties the display-cache bookkeeping
  /// until the follow-up donation refreshes it.
  BrushFrameDrawingState markCelEdited(
    BrushFrameKey key, {
    DirtyTileSet? dirtyTiles,
  }) {
    return _update(
      key,
      (state) => _markCacheDirty(state, dirtyTiles: dirtyTiles),
    );
  }

  BrushFrameDrawingState _markCacheDirty(
    BrushFrameDrawingState state, {
    DirtyTileSet? dirtyTiles,
  }) {
    final next = state.copyWith(
      inactivePreviewDirty: true,
      sourceRevision: state.sourceRevision + 1,
      cacheDirtyTiles: dirtyTiles == null
          ? state.cacheDirtyTiles
          : state.cacheDirtyTiles.union(dirtyTiles),
    );
    final existing = _displayCaches[state.key];
    if (existing != null) {
      _displayCaches[state.key] = existing.copyWith(
        dirty: true,
        sourceRevision: next.sourceRevision,
        dirtyTiles: dirtyTiles == null
            ? existing.dirtyTiles
            : existing.dirtyTiles.union(dirtyTiles),
      );
    }
    return next;
  }

  BrushFrameDrawingState _update(
    BrushFrameKey key,
    BrushFrameDrawingState Function(BrushFrameDrawingState state) update,
  ) {
    final next = update(getOrCreateFrame(key));
    _frames[key] = next;
    return next;
  }
}
