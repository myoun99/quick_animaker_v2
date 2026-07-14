import '../models/bitmap_surface.dart';
import '../models/brush_dab.dart';
import '../models/canvas_size.dart';
import '../models/brush_frame_display_cache.dart';
import '../models/brush_frame_drawing_state.dart';
import '../models/brush_frame_key.dart';
import '../models/brush_paint_command.dart';
import '../models/brush_paint_command_id.dart';
import '../models/brush_paint_command_state.dart';
import '../models/canvas_point.dart';
import '../models/cut_id.dart';
import '../models/dirty_tile_set.dart';
import '../models/layer_id.dart';
import '../models/undo_payload_ref.dart';
import 'bitmap_surface_geometry.dart';

class BrushFrameFlushResult {
  const BrushFrameFlushResult({
    required this.frameKey,
    required this.deferredCommands,
  });

  final BrushFrameKey frameKey;
  final List<BrushPaintCommand> deferredCommands;
}

class BrushLayerFlushPlan {
  const BrushLayerFlushPlan({required this.layerId, required this.frames});

  final LayerId layerId;
  final List<BrushFrameFlushResult> frames;
}

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

  /// Every baked cel for the .qap v2 save payload. Cels that only have
  /// legacy in-session commands (opened from v1 and never edited) bake
  /// here on the way out via [materialize].
  Map<BrushFrameKey, BitmapSurface> bakedSnapshotForSave({
    required BitmapSurface Function(
      BrushFrameKey key,
      List<BrushPaintCommand> commands,
    )
    materialize,
  }) {
    final snapshot = <BrushFrameKey, BitmapSurface>{..._bakedSurfaces};
    for (final entry in _frames.entries) {
      if (snapshot.containsKey(entry.key)) {
        continue;
      }
      final commands = entry.value.allPaintCommandsInDisplayOrder;
      if (commands.isEmpty) {
        continue;
      }
      final surface = materialize(entry.key, commands);
      if (surface.tiles.isNotEmpty) {
        snapshot[entry.key] = surface;
      }
    }
    return snapshot;
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

  /// Whether the cel shows ANY picture content: baked raster truth (v2
  /// opens, donations) or visible paint commands (this-session strokes).
  /// The composite/export/fill resolvers' emptiness oracle — a command
  /// check alone calls every OPENED cel empty (bake-only opens carry no
  /// commands; the picture is the raster).
  bool celHasRenderableContent(BrushFrameKey key) {
    if (_bakedSurfaces.containsKey(key)) {
      return true;
    }
    final frame = _frames[key];
    return frame != null && frame.allPaintCommandsInDisplayOrder.isNotEmpty;
  }

  /// The cel's current pixels WITHOUT a command replay, or null when only
  /// a replay can produce them (a legacy command cel whose cache went
  /// stale) or the cel is empty:
  /// - a VALID display cache at [canvasSize] (donations keep it fresh
  ///   across every commit/undo/redo);
  /// - else the baked truth, when no commands exist that could have
  ///   diverged from it (raw check — an all-hidden cel must NOT serve a
  ///   stale raster).
  BitmapSurface? currentSurfaceWithoutReplay(
    BrushFrameKey key, {
    required CanvasSize canvasSize,
  }) {
    final cached = validPreviewSurfaceOrNull(key);
    if (cached != null && cached.canvasSize == canvasSize) {
      return cached;
    }
    final frame = _frames[key];
    if (frame != null && frame.paintCommands.isNotEmpty) {
      return null;
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

  /// Shifts every stored stroke of [cutId]'s frames by ([dx], [dy]) in canvas
  /// space, for canvas resizes anchored anywhere but the top-left corner.
  /// Coordinates are doubles, so the inverse translation restores them
  /// exactly (used by resize undo).
  void translateCutContent({
    required CutId cutId,
    required double dx,
    required double dy,
  }) {
    if (dx == 0 && dy == 0) {
      return;
    }
    for (final key in _frames.keys.toList()) {
      if (key.cutId != cutId) {
        continue;
      }
      _update(key, (state) {
        final commands = state.paintCommands
            .map(
              (command) => command.copyWith(
                sourceDabs: [
                  for (final dab in command.sourceDabs)
                    dab.copyWith(
                      center: CanvasPoint(
                        x: dab.center.x + dx,
                        y: dab.center.y + dy,
                      ),
                    ),
                ],
              ),
            )
            .toList();
        return _markCacheDirty(state.copyWith(paintCommands: commands));
      });
      // The baked truth shifts as a raster blit (R19): anchored resizes
      // move content by whole pixels, so the round matches the command
      // shift exactly for the integer offsets resize anchors produce.
      final baked = _bakedSurfaces[key];
      if (baked != null) {
        _bakedSurfaces[key] = translateBitmapSurface(
          baked,
          dx: dx.round(),
          dy: dy.round(),
          canvasSize: baked.canvasSize,
        );
      }
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

  /// Rewrites the given commands' dabs IN PLACE (P9 selection transform):
  /// same ids, same list positions, so the frame's stroke z-order is
  /// untouched. Whole-frame cache dirty — an arbitrary rewrite has no
  /// incremental tile delta.
  BrushFrameDrawingState replacePaintCommandDabs(
    BrushFrameKey key,
    Map<BrushPaintCommandId, List<BrushDab>> dabsById,
  ) {
    return _update(key, (state) {
      final commands = state.paintCommands
          .map(
            (command) => dabsById.containsKey(command.id)
                ? command.copyWith(
                    sourceDabs: List<BrushDab>.unmodifiable(
                      dabsById[command.id]!,
                    ),
                  )
                : command,
          )
          .toList();
      return _markCacheDirty(state.copyWith(paintCommands: commands));
    });
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

  /// Resolves the production-facing user undo payload reference back to the
  /// frame-local brush command payload owned by this store.
  ///
  /// Internal bitmap materialization history is intentionally not consulted
  /// here; it is a session-local bridge below the public coordinator/store
  /// boundary, not user-facing undo history.
  BrushPaintCommand? paintCommandForUndoPayload(UndoPayloadRef payloadRef) {
    if (!payloadRef.isPaintCommand || payloadRef.targetKey == null) {
      return null;
    }
    return frameOrNull(
      payloadRef.targetKey!,
    )?.commandById(payloadRef.paintCommandId);
  }

  BrushFrameDrawingState addLivePaintCommand(
    BrushFrameKey key,
    BrushPaintCommand command, {
    DirtyTileSet? dirtyTiles,
  }) {
    final live = command.copyWith(state: BrushPaintCommandState.live);
    return _update(
      key,
      (state) => _markCacheDirty(
        state.copyWith(paintCommands: [...state.paintCommands, live]),
        dirtyTiles: dirtyTiles,
      ),
    );
  }

  BrushFrameDrawingState markPaintCommandHiddenByUndo(
    BrushFrameKey key,
    BrushPaintCommandId id, {
    DirtyTileSet? dirtyTiles,
  }) {
    return _update(
      key,
      (state) => _markCacheDirty(
        state.copyWith(hiddenCommandIds: {...state.hiddenCommandIds, id}),
        dirtyTiles: dirtyTiles,
      ),
    );
  }

  BrushFrameDrawingState restorePaintCommandFromUndo(
    BrushFrameKey key,
    BrushPaintCommandId id, {
    DirtyTileSet? dirtyTiles,
  }) {
    return _update(
      key,
      (state) => _markCacheDirty(
        state.copyWith(
          hiddenCommandIds: {...state.hiddenCommandIds}..remove(id),
        ),
        dirtyTiles: dirtyTiles,
      ),
    );
  }

  BrushFrameDrawingState movePaintCommandToDeferredBake(
    BrushFrameKey key,
    BrushPaintCommandId id,
  ) {
    return _move(key, id, BrushPaintCommandState.deferredBake);
  }

  BrushFrameFlushResult flushFrame(BrushFrameKey key) {
    final state = getOrCreateFrame(key);
    return BrushFrameFlushResult(
      frameKey: key,
      deferredCommands: state.deferredBakePaintCommands,
    );
  }

  BrushFrameDrawingState markDeferredCommandsBaked(BrushFrameKey key) {
    return _update(key, (state) {
      final deferredIds = state.deferredBakePaintCommands
          .map((command) => command.id)
          .toSet();
      final commands = state.paintCommands
          .map(
            (command) => command.state == BrushPaintCommandState.deferredBake
                ? command.copyWith(state: BrushPaintCommandState.baked)
                : command,
          )
          .toList();
      return _markCacheDirty(
        state.copyWith(
          paintCommands: commands,
          bakedPaintCommandIds: {...state.bakedPaintCommandIds, ...deferredIds},
        ),
      );
    });
  }

  BrushLayerFlushPlan flushLayer(LayerId layerId) {
    final frames = _frames.values
        .where((state) => state.key.layerId == layerId)
        .map((state) => flushFrame(state.key))
        .toList();
    return BrushLayerFlushPlan(layerId: layerId, frames: frames);
  }

  BrushFrameDrawingState _move(
    BrushFrameKey key,
    BrushPaintCommandId id,
    BrushPaintCommandState nextState, {
    DirtyTileSet? dirtyTiles,
  }) {
    return _update(key, (state) {
      final commands = state.paintCommands
          .map(
            (command) =>
                command.id == id ? command.copyWith(state: nextState) : command,
          )
          .toList();
      return _markCacheDirty(
        state.copyWith(paintCommands: commands),
        dirtyTiles: dirtyTiles,
      );
    });
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
