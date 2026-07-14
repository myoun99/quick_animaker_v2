import 'dart:io';
import 'dart:isolate';

import '../models/bitmap_surface.dart';
import '../models/canvas_size.dart';
import '../models/brush_frame_display_cache.dart';
import '../models/brush_frame_drawing_state.dart';
import '../models/brush_frame_key.dart';
import '../models/cut_id.dart';
import '../models/dirty_tile_set.dart';
import 'bitmap_surface_geometry.dart';
import 'persistence/brush_drawing_binary_codec.dart';

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
  // Baked raster truth (R19 bake-only / R20-A1 two-tier).
  //
  // A cel's picture IS its baked tile raster. The truth now lives in TWO
  // forms (TVP-style non-visible cel compression, sized for 400-cut TV /
  // 1500-cut theatrical projects in one file):
  //
  //  - HOT: a BitmapSurface, insertion-ordered as an LRU (access
  //    re-inserts). Byte-budgeted by [hotCelByteBudget].
  //  - COLD: a [QapCelBlob] — the cel encoded + deflated, the SAME bytes
  //    the .qap v3 archive stores. Opens land every cel cold (no pixel
  //    decode); first access materializes; over-budget hot cels cool
  //    back down in a background isolate.
  //
  // A key is in exactly one of the two maps. Truth is never evicted —
  // cooling changes representation, not existence. Undo snapshots hold
  // their own surface references and are budgeted separately
  // (HistoryManager.retainedByteBudget), so cooling here never touches
  // history correctness.

  final Map<BrushFrameKey, BitmapSurface> _bakedSurfaces = {};
  final Map<BrushFrameKey, QapCelBlob> _coldCels = {};
  final Map<BrushFrameKey, QapCelScratchRef> _scratchCels = {};
  final Map<BrushFrameKey, int> _hotByteEstimates = {};
  int _hotBytes = 0;
  int _coldBytes = 0;

  /// Hot-tier byte budget. Cels beyond it cool (encode + deflate) in LRU
  /// order in a background isolate. Test-settable.
  int hotCelByteBudget = 1536 * 1024 * 1024;

  /// Cold-tier byte budget (R20-A2 scratch disk): deflated blobs beyond
  /// it spill to per-cel files in the session scratch directory — RAM
  /// holds a bounded working set no matter how many cuts the project
  /// carries. Test-settable.
  int coldCelByteBudget = 1024 * 1024 * 1024;

  /// Bytes currently resident in the hot tier (diagnostics/tests).
  int get hotBakedBytes => _hotBytes;

  /// Blob bytes currently resident in the cold RAM tier
  /// (diagnostics/tests).
  int get coldBakedBytes => _coldBytes;

  /// Keys currently in the cold tier (diagnostics/tests).
  Iterable<BrushFrameKey> get coldCelKeys => _coldCels.keys;

  /// Keys currently spilled to the scratch disk (diagnostics/tests).
  Iterable<BrushFrameKey> get scratchCelKeys => _scratchCels.keys;

  bool isCelCold(BrushFrameKey key) => _coldCels.containsKey(key);

  bool isCelSpilled(BrushFrameKey key) => _scratchCels.containsKey(key);

  /// The cel's baked raster truth, or null for a never-drawn cel. A cold
  /// cel materializes (inflate + decode) and promotes to hot right here;
  /// a spilled cel reads back from its scratch file first — this is the
  /// ONE seam every pixel consumer goes through.
  BitmapSurface? bakedSurfaceOrNull(BrushFrameKey key) {
    final hot = _bakedSurfaces.remove(key);
    if (hot != null) {
      _bakedSurfaces[key] = hot; // LRU touch.
      return hot;
    }
    var cold = _coldCels[key];
    if (cold == null) {
      final scratch = _scratchCels.remove(key);
      if (scratch == null) {
        return null;
      }
      cold = QapCelBlob(File(scratch.filePath).readAsBytesSync());
      _deleteScratchFile(scratch.filePath);
    } else {
      _coldCels.remove(key);
      _coldBytes -= cold.bytes.length;
    }
    final surface = cold.decode().toSurface();
    _storeHot(key, surface);
    // Reseed the display cache from the same object so first paint after
    // a promotion is O(1), mirroring what open used to do eagerly.
    storeRebuiltDisplayCache(key: key, previewSurface: surface);
    _scheduleCooling();
    return surface;
  }

  void _storeHot(BrushFrameKey key, BitmapSurface surface) {
    final previous = _hotByteEstimates.remove(key);
    if (previous != null) {
      _hotBytes -= previous;
    }
    final estimate =
        surface.tiles.length * surface.tileSize * surface.tileSize * 4;
    _bakedSurfaces.remove(key);
    _bakedSurfaces[key] = surface;
    _hotByteEstimates[key] = estimate;
    _hotBytes += estimate;
  }

  void _removeBaked(BrushFrameKey key) {
    _bakedSurfaces.remove(key);
    final cold = _coldCels.remove(key);
    if (cold != null) {
      _coldBytes -= cold.bytes.length;
    }
    final scratch = _scratchCels.remove(key);
    if (scratch != null) {
      _deleteScratchFile(scratch.filePath);
    }
    final estimate = _hotByteEstimates.remove(key);
    if (estimate != null) {
      _hotBytes -= estimate;
    }
  }

  /// Stores [surface] as the cel's baked truth (commit donations and
  /// snapshot restores land here) — always hot: it was just touched.
  void storeBakedSurface(BrushFrameKey key, BitmapSurface surface) {
    if (surface.tiles.isEmpty) {
      _removeBaked(key);
      return;
    }
    final cold = _coldCels.remove(key);
    if (cold != null) {
      _coldBytes -= cold.bytes.length;
    }
    final scratch = _scratchCels.remove(key);
    if (scratch != null) {
      _deleteScratchFile(scratch.filePath);
    }
    _storeHot(key, surface);
    _scheduleCooling();
  }

  /// Every baked cel for the .qap v3 save payload: hot surfaces (the
  /// saver encodes them), cold blobs (already archive bytes — written
  /// through with ZERO re-encode) and scratch refs (the save isolate
  /// reads the files itself). Callers reading scratch files MUST hold
  /// [lockScratchFiles] for the duration or a concurrent materialization
  /// could delete a file mid-save.
  ({
    Map<BrushFrameKey, BitmapSurface> hot,
    Map<BrushFrameKey, QapCelBlob> cold,
    Map<BrushFrameKey, QapCelScratchRef> scratch,
  })
  bakedSnapshotForSave() {
    return (
      hot: {..._bakedSurfaces},
      cold: {..._coldCels},
      scratch: {..._scratchCels},
    );
  }

  /// Replaces the WHOLE store with loaded cels (project open) — all COLD:
  /// no pixel decodes on open, so a 1500-cut project opens in archive-read
  /// time. Frames reseed at sourceRevision 1; first access per cel
  /// materializes. The previous project's scratch files are discarded;
  /// spilling kicks in immediately when the loaded blobs exceed the cold
  /// budget.
  void restoreBaked(Map<BrushFrameKey, QapCelBlob> cels) {
    _frames.clear();
    clearDisplayCaches();
    _bakedSurfaces.clear();
    _coldCels.clear();
    _hotByteEstimates.clear();
    _hotBytes = 0;
    _coldBytes = 0;
    _discardScratchStorage();
    for (final entry in cels.entries) {
      _frames[entry.key] = BrushFrameDrawingState(
        key: entry.key,
        sourceRevision: 1,
      );
      _coldCels[entry.key] = entry.value;
      _coldBytes += entry.value.bytes.length;
    }
    _scheduleSpilling();
  }

  /// Whether the cel shows ANY picture content — the composite/export/
  /// fill resolvers' emptiness oracle. Cold and spilled count:
  /// representation is not existence.
  bool celHasRenderableContent(BrushFrameKey key) =>
      _bakedSurfaces.containsKey(key) ||
      _coldCels.containsKey(key) ||
      _scratchCels.containsKey(key);

  /// The cel's current pixels: a VALID display cache at [canvasSize]
  /// first (donations keep it fresh), else the baked truth (a cold cel
  /// materializes if its recorded size matches). Null = the cel is empty
  /// (or sized for another canvas — resize flows reseed).
  BitmapSurface? currentSurfaceWithoutReplay(
    BrushFrameKey key, {
    required CanvasSize canvasSize,
  }) {
    final cached = validPreviewSurfaceOrNull(key);
    if (cached != null && cached.canvasSize == canvasSize) {
      return cached;
    }
    final hot = _bakedSurfaces[key];
    if (hot != null) {
      return hot.canvasSize == canvasSize ? bakedSurfaceOrNull(key) : null;
    }
    final cold = _coldCels[key];
    if (cold != null && cold.canvasSize == canvasSize) {
      return bakedSurfaceOrNull(key);
    }
    final scratch = _scratchCels[key];
    if (scratch != null && scratch.canvasSize == canvasSize) {
      return bakedSurfaceOrNull(key);
    }
    return null;
  }

  // --- Cooling (hot → cold) -------------------------------------------

  Future<void>? _activeCooling;

  /// Completes when no cooling pass is running (tests).
  Future<void> drainCooling() async {
    while (_activeCooling != null) {
      await _activeCooling;
    }
  }

  void _scheduleCooling() {
    if (_activeCooling != null ||
        _hotBytes <= hotCelByteBudget ||
        _bakedSurfaces.length <= 1) {
      // The length guard both mirrors the loop's never-cool-the-last-hot
      // rule and keeps the completion re-schedule from spinning when the
      // one remaining cel alone exceeds the budget.
      return;
    }
    _activeCooling = _coolLoop().whenComplete(() {
      _activeCooling = null;
      // Work stored while this pass ran (or that this pass could not cool
      // yet — e.g. a lone hot cel that stopped the loop) gets a fresh
      // pass; without this, a skipped schedule during an active pass
      // would never retry.
      _scheduleCooling();
    });
  }

  /// Cools LRU hot cels until the budget holds, one at a time: snapshot
  /// bytes on the main isolate, deflate in a background isolate, then
  /// commit the swap ONLY if the cel's surface is still the identical
  /// object (a donation in between wins and the stale blob is dropped).
  /// The most recently used cel never cools — the one being painted or
  /// displayed must not thrash even if it alone exceeds the budget.
  Future<void> _coolLoop() async {
    while (_hotBytes > hotCelByteBudget && _bakedSurfaces.length > 1) {
      final key = _bakedSurfaces.keys.first;
      final surface = _bakedSurfaces[key]!;
      final entry = QapCelEntry.fromSurface(key, surface);
      final blob = await Isolate.run(() => QapCelBlob.encode(entry));
      if (identical(_bakedSurfaces[key], surface)) {
        _bakedSurfaces.remove(key);
        _hotBytes -= _hotByteEstimates.remove(key)!;
        _coldCels[key] = blob;
        _coldBytes += blob.bytes.length;
        // Drop the derived alias too, or the surface stays resident.
        _displayCaches.remove(key);
        _scheduleSpilling();
      }
    }
  }

  // --- Scratch disk spill (cold → file, R20-A2) ------------------------

  Directory? _scratchDirectory;
  int _scratchFileSeq = 0;
  Future<void>? _activeSpilling;
  int _scratchReadLocks = 0;
  final List<String> _pendingScratchDeletes = [];

  /// Completes when no spill pass is running (tests).
  Future<void> drainSpilling() async {
    while (_activeSpilling != null) {
      await _activeSpilling;
    }
  }

  /// Completes when neither cooling nor spilling is running (tests).
  Future<void> drainTiering() async {
    while (_activeCooling != null || _activeSpilling != null) {
      await drainCooling();
      await drainSpilling();
    }
  }

  /// While held, spilled files are never deleted (deletes defer) — the
  /// save path reads scratch files from another isolate and a concurrent
  /// materialization must not pull one out from under it. Pair with
  /// [unlockScratchFiles] in a finally.
  void lockScratchFiles() {
    _scratchReadLocks += 1;
  }

  void unlockScratchFiles() {
    assert(_scratchReadLocks > 0);
    _scratchReadLocks -= 1;
    if (_scratchReadLocks == 0) {
      for (final path in _pendingScratchDeletes) {
        File(path).delete().ignore();
      }
      _pendingScratchDeletes.clear();
      for (final directory in _pendingScratchDirDeletes) {
        directory.delete(recursive: true).ignore();
      }
      _pendingScratchDirDeletes.clear();
    }
  }

  void _deleteScratchFile(String path) {
    if (_scratchReadLocks > 0) {
      _pendingScratchDeletes.add(path);
      return;
    }
    File(path).delete().ignore();
  }

  final List<Directory> _pendingScratchDirDeletes = [];

  /// Drops the whole scratch directory (project switch) — refs first so
  /// no read can chase a deleted file. Under a scratch lock (a save in
  /// flight) the directory deletion defers with the file deletes.
  void _discardScratchStorage() {
    _scratchCels.clear();
    _pendingScratchDeletes.clear();
    final directory = _scratchDirectory;
    _scratchDirectory = null;
    if (directory == null) {
      return;
    }
    if (_scratchReadLocks > 0) {
      _pendingScratchDirDeletes.add(directory);
      return;
    }
    directory.delete(recursive: true).ignore();
  }

  Directory _ensureScratchDirectory() {
    final existing = _scratchDirectory;
    if (existing != null) {
      return existing;
    }
    final directory = Directory(
      '${Directory.systemTemp.path}/qa_scratch_$pid'
      '_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    _scratchDirectory = directory;
    return directory;
  }

  void _scheduleSpilling() {
    if (_activeSpilling != null ||
        _coldBytes <= coldCelByteBudget ||
        _coldCels.isEmpty) {
      return;
    }
    _activeSpilling = _spillLoop().whenComplete(() {
      _activeSpilling = null;
      _scheduleSpilling();
    });
  }

  /// Spills oldest-cold blobs to per-cel scratch files until the cold
  /// budget holds: async write first, then the swap commits ONLY if the
  /// key still maps to the identical blob (a materialization or donation
  /// in between wins and the file is discarded).
  Future<void> _spillLoop() async {
    while (_coldBytes > coldCelByteBudget && _coldCels.isNotEmpty) {
      final key = _coldCels.keys.first;
      final blob = _coldCels[key]!;
      final file = File(
        '${_ensureScratchDirectory().path}/${_scratchFileSeq++}.celz',
      );
      await file.writeAsBytes(blob.bytes);
      if (identical(_coldCels[key], blob)) {
        _coldCels.remove(key);
        _coldBytes -= blob.bytes.length;
        _scratchCels[key] = QapCelScratchRef(
          filePath: file.path,
          canvasSize: blob.canvasSize,
          tileSize: blob.tileSize,
          byteLength: blob.bytes.length,
        );
      } else {
        _deleteScratchFile(file.path);
      }
    }
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
      // The baked truth travels with the cel (R19) — either tier.
      final baked = _bakedSurfaces.remove(from);
      if (baked != null) {
        _bakedSurfaces[to] = baked;
        _hotByteEstimates[to] = _hotByteEstimates.remove(from)!;
      }
      final cold = _coldCels.remove(from);
      if (cold != null) {
        _coldCels[to] = cold;
      }
      final scratch = _scratchCels.remove(from);
      if (scratch != null) {
        _scratchCels[to] = scratch;
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
    for (final key in _celKeysOfCut(cutId)) {
      // Cold cels of the cut materialize first (cut-scoped = bounded).
      final surface = bakedSurfaceOrNull(key)!;
      _storeHot(
        key,
        translateBitmapSurface(
          surface,
          dx: dx.round(),
          dy: dy.round(),
          canvasSize: surface.canvasSize,
        ),
      );
      markCelEdited(key);
    }
    _scheduleCooling();
  }

  List<BrushFrameKey> _celKeysOfCut(CutId cutId) => [
    for (final key in _bakedSurfaces.keys)
      if (key.cutId == cutId) key,
    for (final key in _coldCels.keys)
      if (key.cutId == cutId) key,
    for (final key in _scratchCels.keys)
      if (key.cutId == cutId) key,
  ];

  /// Adopts a new canvas size for every baked surface (R19: a resize is
  /// a raster crop/extend — top-left anchored, every tile kept, so
  /// shrinking then growing back restores exactly). Cold cels transform
  /// one at a time through a decode→resize→re-encode round trip and STAY
  /// cold — a 1500-cel project must never materialize whole for a resize.
  void resizeBakedSurfaces(CanvasSize canvasSize) {
    for (final key in _bakedSurfaces.keys.toList()) {
      _storeHot(
        key,
        resizeBitmapSurfaceCanvas(_bakedSurfaces[key]!, canvasSize),
      );
    }
    for (final key in _coldCels.keys.toList()) {
      final cold = _coldCels[key]!;
      if (cold.canvasSize == canvasSize) {
        continue;
      }
      final resized = QapCelBlob.encode(
        QapCelEntry.fromSurface(
          key,
          resizeBitmapSurfaceCanvas(cold.decode().toSurface(), canvasSize),
        ),
      );
      _coldBytes += resized.bytes.length - cold.bytes.length;
      _coldCels[key] = resized;
    }
    for (final key in _scratchCels.keys.toList()) {
      final scratch = _scratchCels[key]!;
      if (scratch.canvasSize == canvasSize) {
        continue;
      }
      final file = File(scratch.filePath);
      final resized = QapCelBlob.encode(
        QapCelEntry.fromSurface(
          key,
          resizeBitmapSurfaceCanvas(
            QapCelBlob(file.readAsBytesSync()).decode().toSurface(),
            canvasSize,
          ),
        ),
      );
      file.writeAsBytesSync(resized.bytes);
      _scratchCels[key] = QapCelScratchRef(
        filePath: scratch.filePath,
        canvasSize: canvasSize,
        tileSize: resized.tileSize,
        byteLength: resized.bytes.length,
      );
    }
  }

  /// The cut's baked surfaces by key — cold cels of the cut materialize
  /// (cut-scoped = bounded); surfaces are immutable, so the snapshot is
  /// reference-cheap from there (the anchored-resize command keeps one
  /// for its exact undo).
  Map<BrushFrameKey, BitmapSurface> bakedSurfacesForCut(CutId cutId) {
    return {
      for (final key in _celKeysOfCut(cutId)) key: bakedSurfaceOrNull(key)!,
    };
  }

  /// Restores a [bakedSurfacesForCut] snapshot (anchored-resize undo):
  /// the cut's baked set becomes exactly the snapshot again.
  void restoreBakedForCut(
    CutId cutId,
    Map<BrushFrameKey, BitmapSurface> snapshot,
  ) {
    for (final key in _celKeysOfCut(cutId)) {
      _removeBaked(key);
    }
    for (final entry in snapshot.entries) {
      _storeHot(entry.key, entry.value);
      // The display caches follow the restored truth.
      storeRebuiltDisplayCache(key: entry.key, previewSurface: entry.value);
    }
    _scheduleCooling();
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

/// A cel spilled to the scratch disk (R20-A2): the file holds the exact
/// [QapCelBlob] bytes; canvas geometry rides along so size checks never
/// touch the disk. Paths cross the save isolate cheaply — the saver reads
/// the file itself (hold [BrushFrameStore.lockScratchFiles] while it does).
class QapCelScratchRef {
  const QapCelScratchRef({
    required this.filePath,
    required this.canvasSize,
    required this.tileSize,
    required this.byteLength,
  });

  final String filePath;
  final CanvasSize canvasSize;
  final int tileSize;
  final int byteLength;
}
