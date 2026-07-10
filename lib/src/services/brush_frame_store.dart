import '../models/bitmap_surface.dart';
import '../models/brush_dab.dart';
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
  final Map<BrushFrameKey, BrushFrameDisplayCache> _displayCaches = {};

  BrushFrameDrawingState getOrCreateFrame(BrushFrameKey key) {
    return _frames.putIfAbsent(key, () => BrushFrameDrawingState(key: key));
  }

  BrushFrameDrawingState? frameOrNull(BrushFrameKey key) => _frames[key];

  BrushFrameDisplayCache? displayCacheOrNull(BrushFrameKey key) =>
      _displayCaches[key];

  bool hasValidDisplayCache(BrushFrameKey key) =>
      _displayCaches[key]?.isValid ?? false;

  BitmapSurface? validPreviewSurfaceOrNull(BrushFrameKey key) {
    final cache = _displayCaches[key];
    return cache != null && cache.isValid ? cache.previewSurface : null;
  }

  /// Drops every derived display cache, e.g. after a canvas resize makes the
  /// cached preview surfaces the wrong size. Source paint commands are kept.
  void clearDisplayCaches() {
    _displayCaches.clear();
  }

  /// Every drawn frame's VISIBLE commands (source dabs included) — the
  /// .qap save payload (P3). The same command list export replays
  /// (allPaintCommandsInDisplayOrder), so a saved file reproduces exactly
  /// the picture on screen; hidden-by-undo and bake bookkeeping stay
  /// session-local.
  Map<BrushFrameKey, List<BrushPaintCommand>> drawingsSnapshotForSave() {
    return {
      for (final entry in _frames.entries)
        if (entry.value.allPaintCommandsInDisplayOrder.isNotEmpty)
          entry.key: entry.value.allPaintCommandsInDisplayOrder,
    };
  }

  /// Replaces the WHOLE store with loaded drawings (project open): every
  /// frame reseeds live at sourceRevision 1, so pre-load display caches and
  /// composite signatures can never match stale content.
  void restoreDrawings(Map<BrushFrameKey, List<BrushPaintCommand>> drawings) {
    _frames.clear();
    _displayCaches.clear();
    for (final entry in drawings.entries) {
      _frames[entry.key] = BrushFrameDrawingState(
        key: entry.key,
        paintCommands: entry.value,
        sourceRevision: 1,
      );
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
    _displayCaches[key] = cache;
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
