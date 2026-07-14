import 'dart:collection';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'dart:typed_data';

import '../models/bitmap_tile.dart';

/// The native engine core's FFI bindings (R18 A-track).
///
/// LOAD-FALLBACK DISCIPLINE: every native function has a Dart REFERENCE
/// implementation that remains the source of truth for semantics. When
/// the library cannot be loaded (flutter_tester, an unsupported platform,
/// a packaging problem) callers silently use the Dart path — the app
/// never breaks, it just runs at Dart speed. Byte-parity between the two
/// is pinned by tests, so the native path can never silently diverge.
///
/// Tests can point at a locally built binary with the QA_ENGINE_PATH
/// environment variable.
class QaNativeEngine {
  QaNativeEngine._(
    this._premultiplyRgba,
    this._floodFillStep,
    this._fillPaperRect,
    this._fillComposeTile,
    this._fillFinishMask,
    this._dabBlendTiles,
    this._stampBlendTiles,
  ) : _spec = calloc<QaDabSpecStruct>();

  static const int _abiVersion = 8;

  final void Function(Pointer<Uint8> pixels, int pixelCount) _premultiplyRgba;

  final int Function(
    Pointer<Uint8> rgb,
    Pointer<Uint8> filled,
    Pointer<Uint8> composed,
    int width,
    int height,
    int composeTileShift,
    int tilesX,
    int seedR,
    int seedG,
    int seedB,
    int tolerance,
    Pointer<Int32> stack,
    Pointer<Int32> stackSize,
    int stackCapacity,
    Pointer<Int32> candidates,
    int candidatesCapacity,
    Pointer<Int32> bounds,
  )
  _floodFillStep;

  final void Function(
    Pointer<Uint8> rgb,
    int rasterWidth,
    int left,
    int top,
    int rightExclusive,
    int bottomExclusive,
    int paperR,
    int paperG,
    int paperB,
  )
  _fillPaperRect;

  final void Function(
    Pointer<Uint8> rgb,
    int rasterWidth,
    Pointer<Uint8> tilePixels,
    int tileSize,
    int baseX,
    int baseY,
    int clipLeft,
    int clipTop,
    int clipRightExclusive,
    int clipBottomExclusive,
    int opacityInt,
  )
  _fillComposeTile;

  final void Function(
    Pointer<Uint8> filled,
    int canvasWidth,
    int cropLeft,
    int cropTop,
    int regionWidth,
    int regionHeight,
    int expandPx,
    int antiAlias,
    Pointer<Uint8> mask,
    Pointer<Uint8> scratch,
  )
  _fillFinishMask;

  final void Function(
    Pointer<QaTileSpanStruct> tiles,
    int tileCount,
    int tileSize,
    Pointer<QaDabSpecStruct> spec,
    Pointer<Uint8> changedOut,
  )
  _dabBlendTiles;

  final void Function(
    Pointer<QaTileSpanStruct> tiles,
    int tileCount,
    int tileSize,
    Pointer<Uint8> stamp,
    int stampWidth,
    int stampLeft,
    int stampTop,
    double opacity,
    int erase,
    Pointer<Uint8> changedOut,
  )
  _stampBlendTiles;

  static QaNativeEngine? _instance;
  static bool _loadAttempted = false;

  /// Test hooks: an explicit binary path (parity tests point at the
  /// locally built DLL) and a force-Dart switch (the parity test's
  /// reference side).
  static String? debugLibraryPathOverride;
  static bool debugForceDartFallback = false;

  static void debugResetForTests() {
    _instance = null;
    _loadAttempted = false;
  }

  /// The loaded engine, or null (Dart fallback). Load happens once.
  static QaNativeEngine? get instance {
    if (debugForceDartFallback) {
      return null;
    }
    if (!_loadAttempted) {
      _loadAttempted = true;
      _instance = _tryLoad();
    }
    return _instance;
  }

  static QaNativeEngine? _tryLoad() {
    final library = _tryOpen();
    if (library == null) {
      return null;
    }
    try {
      final abi = library
          .lookupFunction<Int32 Function(), int Function()>(
            'qa_engine_abi_version',
          )
          .call();
      if (abi != _abiVersion) {
        return null;
      }
      // Struct-layout paranoia: both sides must agree on the spec's exact
      // byte layout, or every field read is garbage. Any mismatch means
      // Dart fallback, never a corrupt blend.
      final specSize = library
          .lookupFunction<Int32 Function(), int Function()>(
            'qa_dab_spec_sizeof',
          )
          .call();
      if (specSize != sizeOf<QaDabSpecStruct>()) {
        return null;
      }
      final spanSize = library
          .lookupFunction<Int32 Function(), int Function()>(
            'qa_tile_span_sizeof',
          )
          .call();
      if (spanSize != sizeOf<QaTileSpanStruct>()) {
        return null;
      }
      final premultiplyRgba = library
          .lookupFunction<
            Void Function(Pointer<Uint8>, Int32),
            void Function(Pointer<Uint8>, int)
          >('qa_premultiply_rgba');
      final floodFillStep = library
          .lookupFunction<
            Int32 Function(
              Pointer<Uint8>,
              Pointer<Uint8>,
              Pointer<Uint8>,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Pointer<Int32>,
              Pointer<Int32>,
              Int32,
              Pointer<Int32>,
              Int32,
              Pointer<Int32>,
            ),
            int Function(
              Pointer<Uint8>,
              Pointer<Uint8>,
              Pointer<Uint8>,
              int,
              int,
              int,
              int,
              int,
              int,
              int,
              int,
              Pointer<Int32>,
              Pointer<Int32>,
              int,
              Pointer<Int32>,
              int,
              Pointer<Int32>,
            )
          >('qa_flood_fill_step');
      final fillPaperRect = library
          .lookupFunction<
            Void Function(
              Pointer<Uint8>,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
            ),
            void Function(
              Pointer<Uint8>,
              int,
              int,
              int,
              int,
              int,
              int,
              int,
              int,
            )
          >('qa_fill_paper_rect');
      final fillComposeTile = library
          .lookupFunction<
            Void Function(
              Pointer<Uint8>,
              Int32,
              Pointer<Uint8>,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
            ),
            void Function(
              Pointer<Uint8>,
              int,
              Pointer<Uint8>,
              int,
              int,
              int,
              int,
              int,
              int,
              int,
              int,
            )
          >('qa_fill_compose_tile');
      final fillFinishMask = library
          .lookupFunction<
            Void Function(
              Pointer<Uint8>,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Pointer<Uint8>,
              Pointer<Uint8>,
            ),
            void Function(
              Pointer<Uint8>,
              int,
              int,
              int,
              int,
              int,
              int,
              int,
              Pointer<Uint8>,
              Pointer<Uint8>,
            )
          >('qa_fill_finish_mask');
      final dabBlendTiles = library
          .lookupFunction<
            Void Function(
              Pointer<QaTileSpanStruct>,
              Int32,
              Int32,
              Pointer<QaDabSpecStruct>,
              Pointer<Uint8>,
            ),
            void Function(
              Pointer<QaTileSpanStruct>,
              int,
              int,
              Pointer<QaDabSpecStruct>,
              Pointer<Uint8>,
            )
          >('qa_dab_blend_tiles');
      final stampBlendTiles = library
          .lookupFunction<
            Void Function(
              Pointer<QaTileSpanStruct>,
              Int32,
              Int32,
              Pointer<Uint8>,
              Int32,
              Int32,
              Int32,
              Double,
              Int32,
              Pointer<Uint8>,
            ),
            void Function(
              Pointer<QaTileSpanStruct>,
              int,
              int,
              Pointer<Uint8>,
              int,
              int,
              int,
              double,
              int,
              Pointer<Uint8>,
            )
          >('qa_stamp_blend_tiles');
      return QaNativeEngine._(
        premultiplyRgba,
        floodFillStep,
        fillPaperRect,
        fillComposeTile,
        fillFinishMask,
        dabBlendTiles,
        stampBlendTiles,
      );
    } on Object {
      return null;
    }
  }

  static DynamicLibrary? _tryOpen() {
    final overridePath =
        debugLibraryPathOverride ?? Platform.environment['QA_ENGINE_PATH'];
    for (final candidate in [
      if (overridePath != null && overridePath.isNotEmpty) overridePath,
      if (Platform.isWindows) 'qa_engine.dll',
      if (Platform.isLinux) 'libqa_engine.so',
      if (Platform.isMacOS) 'libqa_engine.dylib',
    ]) {
      try {
        return DynamicLibrary.open(candidate);
      } on Object {
        continue;
      }
    }
    return null;
  }

  /// Uploaded stamp RGBA byte buffers keyed by the SOURCE Uint8List's
  /// identity (BrushStampImage.rgba is a final field, so the identity is
  /// stable for the stamp's lifetime). Small LRU — a move session
  /// re-commits the SAME lift stamp on every drag move, so after the
  /// first upload the whole stamp blend is zero-copy (A-1.5). A freshly
  /// uploaded entry is always the most recent, so it can never be
  /// evicted while its dab is still blending.
  final LinkedHashMap<Object, Pointer<Uint8>> _stampUploads =
      LinkedHashMap.identity();
  final Map<Object, int> _stampUploadSizes = HashMap.identity();
  int _stampUploadBytes = 0;
  static const int _stampUploadCap = 4;

  /// Entry-count AND byte-budgeted (R19-8K): a full-canvas fill stamp at
  /// 8000² is 256MB — four of those resident was a 1GB RSS bomb. The
  /// newest entry always survives even when it alone exceeds the budget.
  static const int stampUploadByteBudget = 320 * 1024 * 1024;

  /// Uploads [bytes] once (identity-cached) and returns the native copy.
  Pointer<Uint8> uploadStampBytes(Uint8List bytes) {
    final cached = _stampUploads.remove(bytes);
    if (cached != null) {
      _stampUploads[bytes] = cached;
      return cached;
    }
    // malloc, not calloc: the copy below overwrites every byte — the
    // calloc memset doubled an 8000² fill stamp's 256MB upload traffic.
    final pointer = malloc<Uint8>(bytes.length);
    pointer.asTypedList(bytes.length).setAll(0, bytes);
    _stampUploads[bytes] = pointer;
    _stampUploadSizes[bytes] = bytes.length;
    _stampUploadBytes += bytes.length;
    while (_stampUploads.length > 1 &&
        (_stampUploads.length > _stampUploadCap ||
            _stampUploadBytes > stampUploadByteBudget)) {
      final oldest = _stampUploads.keys.first;
      malloc.free(_stampUploads.remove(oldest)!);
      _stampUploadBytes -= _stampUploadSizes.remove(oldest)!;
    }
    return pointer;
  }

  // -------------------------------------------------------------------
  // Flood fill (R18 A-2b): engine-persistent, grow-only buffers. ONE
  // fill runs at a time (a fill tap is synchronous and single-shot), so
  // the lazy raster and the stepper share these across calls.

  Pointer<Uint8> _floodRgb = nullptr;
  int _floodRgbLength = 0;
  Pointer<Uint8> _floodComposed = nullptr;
  int _floodComposedLength = 0;
  Pointer<Uint8> _floodFilled = nullptr;
  int _floodFilledLength = 0;
  Pointer<Int32> _floodStack = nullptr;
  int _floodStackCapacity = 0;
  Pointer<Int32> _floodCandidates = nullptr;
  int _floodCandidatesCapacity = 0;
  Pointer<Int32> _floodStackSize = nullptr;
  Pointer<Int32> _floodBounds = nullptr;

  Pointer<Uint8> _ensureUint8(Pointer<Uint8> current, int have, int need) {
    if (have >= need) {
      return current;
    }
    if (current != nullptr) {
      calloc.free(current);
    }
    return calloc<Uint8>(need);
  }

  /// Acquires the shared lazy-raster buffers for one fill:
  /// [QaFloodNativeHandles.rgbView] (`width*height*3`, contents
  /// unspecified — only composed tiles are ever read) and
  /// [QaFloodNativeHandles.composedView] (one byte per compose tile,
  /// zeroed here). [composeTileSize] must be a power of two.
  QaFloodNativeHandles acquireFloodRaster({
    required int width,
    required int height,
    required int composeTileSize,
  }) {
    assert(
      composeTileSize > 0 && (composeTileSize & (composeTileSize - 1)) == 0,
      'composeTileSize must be a power of two',
    );
    final shift = composeTileSize.bitLength - 1;
    final tilesX = (width + composeTileSize - 1) ~/ composeTileSize;
    final tilesY = (height + composeTileSize - 1) ~/ composeTileSize;

    final rgbLength = width * height * 3;
    _floodRgb = _ensureUint8(_floodRgb, _floodRgbLength, rgbLength);
    if (_floodRgbLength < rgbLength) {
      _floodRgbLength = rgbLength;
    }
    final composedLength = tilesX * tilesY;
    _floodComposed = _ensureUint8(
      _floodComposed,
      _floodComposedLength,
      composedLength,
    );
    if (_floodComposedLength < composedLength) {
      _floodComposedLength = composedLength;
    }
    final composedView = _floodComposed.asTypedList(composedLength);
    composedView.fillRange(0, composedLength, 0);

    return QaFloodNativeHandles._(
      rgbView: _floodRgb.asTypedList(rgbLength),
      composedView: composedView,
      width: width,
      height: height,
      tilesX: tilesX,
      composeTileShift: shift,
    );
  }

  /// Persistent grow-only scratch for [fillComposeTile]'s source tile.
  Pointer<Uint8> _composeTileScratch = nullptr;
  int _composeTileScratchLength = 0;

  /// Fills a rect of the native fill raster with the paper color
  /// (A-2c) — identical to the Dart paper loop.
  void fillPaperRect({
    required QaFloodNativeHandles handles,
    required int left,
    required int top,
    required int rightExclusive,
    required int bottomExclusive,
    required int paperR,
    required int paperG,
    required int paperB,
  }) {
    _fillPaperRect(
      _floodRgb,
      handles.width,
      left,
      top,
      rightExclusive,
      bottomExclusive,
      paperR,
      paperG,
      paperB,
    );
  }

  /// Integer source-over of one surface-tile clip onto the native fill
  /// raster (A-2c) — byte-identical to the Dart compose loop. The tile
  /// bytes are staged once through a persistent scratch.
  void fillComposeTile({
    required QaFloodNativeHandles handles,
    required BitmapTile tile,
    required int baseX,
    required int baseY,
    required int clipLeft,
    required int clipTop,
    required int clipRightExclusive,
    required int clipBottomExclusive,
    required int opacityInt,
  }) {
    final byteLength = tile.size * tile.size * BitmapTile.bytesPerPixel;
    if (_composeTileScratchLength < byteLength) {
      if (_composeTileScratch != nullptr) {
        calloc.free(_composeTileScratch);
      }
      _composeTileScratch = calloc<Uint8>(byteLength);
      _composeTileScratchLength = byteLength;
    }
    tile.copyPixelsInto(_composeTileScratch.asTypedList(byteLength));
    _fillComposeTile(
      _floodRgb,
      handles.width,
      _composeTileScratch,
      tile.size,
      baseX,
      baseY,
      clipLeft,
      clipTop,
      clipRightExclusive,
      clipBottomExclusive,
      opacityInt,
    );
  }

  /// Runs the whole native flood from the (already composed, already
  /// filled-marked) seed: steps the C kernel, composes candidate tiles
  /// through [ensureComposed], re-tests candidates (filled dedupes) and
  /// re-enters until the stack drains. Returns the filled mask as a view
  /// over engine memory (valid until the next fill) plus the bounds —
  /// result set identical to the Dart reference by construction
  /// (parity-pinned).
  ({Uint8List filled, int minX, int maxX, int minY, int maxY}) floodFillRun({
    required QaFloodNativeHandles handles,
    required int seedX,
    required int seedY,
    required int seedR,
    required int seedG,
    required int seedB,
    required int tolerance,
    required void Function(int index) ensureComposed,
  }) {
    final width = handles.width;
    final height = handles.height;
    final pixelCount = width * height;

    _floodFilled = _ensureUint8(_floodFilled, _floodFilledLength, pixelCount);
    if (_floodFilledLength < pixelCount) {
      _floodFilledLength = pixelCount;
    }
    final filledView = _floodFilled.asTypedList(pixelCount);
    filledView.fillRange(0, pixelCount, 0);

    var stackCapacity = _floodStackCapacity;
    if (stackCapacity < width + 4096) {
      stackCapacity = width * 4 + 65536;
      if (_floodStack != nullptr) {
        calloc.free(_floodStack);
      }
      _floodStack = calloc<Int32>(stackCapacity);
      _floodStackCapacity = stackCapacity;
    }
    final candidatesCapacity = 8 * width + 2048;
    if (_floodCandidatesCapacity < candidatesCapacity) {
      if (_floodCandidates != nullptr) {
        calloc.free(_floodCandidates);
      }
      _floodCandidates = calloc<Int32>(candidatesCapacity);
      _floodCandidatesCapacity = candidatesCapacity;
    }
    if (_floodStackSize == nullptr) {
      _floodStackSize = calloc<Int32>(1);
      _floodBounds = calloc<Int32>(4);
    }

    final seedIndex = seedY * width + seedX;
    filledView[seedIndex] = 255;
    _floodStack.value = seedIndex;
    _floodStackSize.value = 1;
    final bounds = _floodBounds.asTypedList(4);
    bounds[0] = seedX;
    bounds[1] = seedX;
    bounds[2] = seedY;
    bounds[3] = seedY;

    final rgbView = handles.rgbView;
    final composedView = handles.composedView;
    while (true) {
      final candidateCount = _floodFillStep(
        _floodRgb,
        _floodFilled,
        _floodComposed,
        width,
        height,
        handles.composeTileShift,
        handles.tilesX,
        seedR,
        seedG,
        seedB,
        tolerance,
        _floodStack,
        _floodStackSize,
        _floodStackCapacity,
        _floodCandidates,
        _floodCandidatesCapacity,
        _floodBounds,
      );
      if (candidateCount > 0) {
        final candidates = _floodCandidates.asTypedList(candidateCount);
        for (var i = 0; i < candidateCount; i += 1) {
          ensureComposed(candidates[i]);
        }
        var stackSize = _floodStackSize.value;
        for (var i = 0; i < candidateCount; i += 1) {
          final index = candidates[i];
          if (filledView[index] != 0) {
            continue;
          }
          final tile =
              ((index ~/ width) >> handles.composeTileShift) * handles.tilesX +
              ((index % width) >> handles.composeTileShift);
          if (composedView[tile] == 0) {
            // The callback failed its contract; a silent retry would spin
            // forever, so fail loudly.
            throw StateError(
              'floodFillRun: ensureComposed left tile $tile uncomposed',
            );
          }
          final base = index * 3;
          if ((rgbView[base] - seedR).abs() <= tolerance &&
              (rgbView[base + 1] - seedG).abs() <= tolerance &&
              (rgbView[base + 2] - seedB).abs() <= tolerance) {
            filledView[index] = 255;
            if (stackSize >= _floodStackCapacity) {
              _growFloodStack(stackSize);
            }
            _floodStack.asTypedList(_floodStackCapacity)[stackSize] = index;
            stackSize += 1;
          }
        }
        _floodStackSize.value = stackSize;
        continue;
      }
      if (_floodStackSize.value == 0) {
        break;
      }
      // No candidates but work remains: the stack headroom guard tripped.
      _growFloodStack(_floodStackSize.value);
    }

    return (
      filled: filledView,
      minX: bounds[0],
      maxX: bounds[1],
      minY: bounds[2],
      maxY: bounds[3],
    );
  }

  /// Grow-only region scratches for [finishFillMask]'s double buffer.
  Pointer<Uint8> _maskScratchA = nullptr;
  int _maskScratchALength = 0;
  Pointer<Uint8> _maskScratchB = nullptr;
  int _maskScratchBLength = 0;

  /// Crop + expand + anti-alias over the native flood mask (A-2d) —
  /// byte-identical to the Dart tail. Returns a fresh heap mask the
  /// caller owns.
  Uint8List finishFillMask({
    required int canvasWidth,
    required int cropLeft,
    required int cropTop,
    required int regionWidth,
    required int regionHeight,
    required int expandPx,
    required bool antiAlias,
  }) {
    final regionLength = regionWidth * regionHeight;
    if (_maskScratchALength < regionLength) {
      if (_maskScratchA != nullptr) {
        calloc.free(_maskScratchA);
      }
      _maskScratchA = calloc<Uint8>(regionLength);
      _maskScratchALength = regionLength;
    }
    if (_maskScratchBLength < regionLength) {
      if (_maskScratchB != nullptr) {
        calloc.free(_maskScratchB);
      }
      _maskScratchB = calloc<Uint8>(regionLength);
      _maskScratchBLength = regionLength;
    }
    _fillFinishMask(
      _floodFilled,
      canvasWidth,
      cropLeft,
      cropTop,
      regionWidth,
      regionHeight,
      expandPx,
      antiAlias ? 1 : 0,
      _maskScratchA,
      _maskScratchB,
    );
    return Uint8List.fromList(_maskScratchA.asTypedList(regionLength));
  }

  void _growFloodStack(int liveEntries) {
    final newCapacity = _floodStackCapacity * 2;
    final grown = calloc<Int32>(newCapacity);
    grown
        .asTypedList(newCapacity)
        .setRange(0, liveEntries, _floodStack.asTypedList(liveEntries));
    calloc.free(_floodStack);
    _floodStack = grown;
    _floodStackCapacity = newCapacity;
  }

  /// Persistent grow-only scratch for [premultiplyRgba]'s round trip.
  Pointer<Uint8> _premultiplyScratch = nullptr;
  int _premultiplyScratchLength = 0;

  /// Premultiplies [pixels] (straight-alpha RGBA) IN PLACE through the
  /// native kernel — byte-identical to the Dart reference (Skia
  /// mul-div-255 rounding). Two memcpys through a persistent scratch
  /// replace the 65k-iteration Dart loop per tile (A-2a).
  void premultiplyRgba(Uint8List pixels) {
    if (_premultiplyScratchLength < pixels.length) {
      if (_premultiplyScratch != nullptr) {
        calloc.free(_premultiplyScratch);
      }
      _premultiplyScratch = calloc<Uint8>(pixels.length);
      _premultiplyScratchLength = pixels.length;
    }
    final view = _premultiplyScratch.asTypedList(pixels.length);
    view.setAll(0, pixels);
    _premultiplyRgba(_premultiplyScratch, pixels.length ~/ 4);
    pixels.setAll(0, view);
  }

  /// Grow-only batch buffers (R18 A-3a): the tile spans of one dab and
  /// the per-tile changed flags, staged once per dab and fanned across
  /// the C worker pool.
  Pointer<QaTileSpanStruct> _tileSpans = nullptr;
  int _tileSpanCapacity = 0;
  Pointer<Uint8> _batchChanged = nullptr;
  int _batchChangedCapacity = 0;

  /// Makes room for [count] spans in the current batch.
  void ensureTileSpanBatch(int count) {
    if (_tileSpanCapacity < count) {
      if (_tileSpans != nullptr) {
        calloc.free(_tileSpans);
      }
      _tileSpans = calloc<QaTileSpanStruct>(count);
      _tileSpanCapacity = count;
    }
    if (_batchChangedCapacity < count) {
      if (_batchChanged != nullptr) {
        calloc.free(_batchChanged);
      }
      _batchChanged = calloc<Uint8>(count);
      _batchChangedCapacity = count;
    }
  }

  /// Stages the [index]-th span of the batch ([ensureTileSpanBatch] first).
  void setTileSpan(
    int index, {
    required Pointer<Uint8> tilePixels,
    required int tileLeft,
    required int tileTop,
    required int spanLeft,
    required int spanRightExclusive,
    required int spanTop,
    required int spanBottomExclusive,
  }) {
    final span = _tileSpans[index];
    span.tilePixels = tilePixels;
    span.tileLeft = tileLeft;
    span.tileTop = tileTop;
    span.spanLeft = spanLeft;
    span.spanRightExclusive = spanRightExclusive;
    span.spanTop = spanTop;
    span.spanBottomExclusive = spanBottomExclusive;
    span.reserved = 0;
  }

  /// Blends the prepared dab ([prepareDab]) into every staged span in ONE
  /// call, fanned across the worker pool (tiles are disjoint, so results
  /// are byte-identical to the sequential loop). Returns the per-tile
  /// changed flags (valid until the next batch).
  Uint8List dabBlendTiles({required int count, required int tileSize}) {
    _dabBlendTiles(_tileSpans, count, tileSize, _spec, _batchChanged);
    return _batchChanged.asTypedList(count);
  }

  /// The stamp counterpart of [dabBlendTiles].
  Uint8List stampBlendTiles({
    required int count,
    required int tileSize,
    required Pointer<Uint8> stampBytes,
    required int stampWidth,
    required int stampLeft,
    required int stampTop,
    required double opacity,
    required bool erase,
  }) {
    _stampBlendTiles(
      _tileSpans,
      count,
      tileSize,
      stampBytes,
      stampWidth,
      stampLeft,
      stampTop,
      opacity,
      erase ? 1 : 0,
      _batchChanged,
    );
    return _batchChanged.asTypedList(count);
  }

  // -------------------------------------------------------------------
  // Native-backed tile scratch buffers (R18 A-1).
  //
  // The materializer's per-tile scratch lives in native memory: the Dart
  // side works on an asTypedList VIEW (so the Dart fallback loops and the
  // stamp path run unchanged), while the native kernel gets the raw
  // pointer — zero tile copies per dab. Buffers are pooled per byte
  // length and reused across commits.

  final Map<int, List<QaNativeTileBuffer>> _tilePool = {};

  /// BYTE-budgeted (R19-8K): the old 32-buffers-per-length cap made an
  /// 8000² full-canvas commit malloc/free ~250MB of tile scratch EVERY
  /// fill (992 of its 1024 tiles missed the pool) — one full 8K frame's
  /// worth now stays pooled.
  static const int tilePoolByteBudget = 320 * 1024 * 1024;
  int _tilePoolBytes = 0;

  /// A pooled buffer; [zeroed] skips the memset when the caller overwrites
  /// every byte anyway (existing-tile copy-in).
  QaNativeTileBuffer acquireTileBuffer(int byteLength, {required bool zeroed}) {
    final pool = _tilePool[byteLength];
    if (pool != null && pool.isNotEmpty) {
      final buffer = pool.removeLast();
      _tilePoolBytes -= byteLength;
      if (zeroed) {
        buffer.view.fillRange(0, byteLength, 0);
      }
      return buffer;
    }
    // malloc, not calloc: fresh buffers are either explicitly zeroed here
    // or fully overwritten by the copy-in — calloc's memset was pure
    // waste at full-canvas scale.
    final pointer = malloc<Uint8>(byteLength);
    final view = pointer.asTypedList(byteLength);
    if (zeroed) {
      view.fillRange(0, byteLength, 0);
    }
    return QaNativeTileBuffer._(pointer, view);
  }

  void releaseTileBuffer(QaNativeTileBuffer buffer) {
    final byteLength = buffer.view.length;
    if (_tilePoolBytes + byteLength > tilePoolByteBudget) {
      malloc.free(buffer.pointer);
      return;
    }
    _tilePool.putIfAbsent(byteLength, () => []).add(buffer);
    _tilePoolBytes += byteLength;
  }

  // -------------------------------------------------------------------
  // Generic dab blend (R18 A-1).

  final Pointer<QaDabSpecStruct> _spec;

  /// Uploaded mask alphas keyed by the SOURCE Float64List's identity
  /// (BrushTipMask.alphaNormalized is `late final`, so the identity is
  /// stable for a mask's lifetime). Small LRU — one stroke reuses the
  /// same two or three masks for every dab.
  final LinkedHashMap<Object, Pointer<Double>> _maskUploads =
      LinkedHashMap.identity();
  static const int _maskUploadCap = 8;

  Pointer<Double> _uploadMask(Float64List alphaNormalized) {
    final cached = _maskUploads.remove(alphaNormalized);
    if (cached != null) {
      _maskUploads[alphaNormalized] = cached;
      return cached;
    }
    final pointer = calloc<Double>(alphaNormalized.length);
    pointer.asTypedList(alphaNormalized.length).setAll(0, alphaNormalized);
    _maskUploads[alphaNormalized] = pointer;
    while (_maskUploads.length > _maskUploadCap) {
      final oldest = _maskUploads.keys.first;
      calloc.free(_maskUploads.remove(oldest)!);
    }
    return pointer;
  }

  /// One grow-only arena for the per-dab lattice arrays — copied once per
  /// dab (prepareDab), read by every tile call of that dab.
  Pointer<Uint8> _arena = nullptr;
  int _arenaCapacity = 0;
  int _arenaOffset = 0;

  void _arenaReset(int byteBudget) {
    if (_arenaCapacity < byteBudget) {
      if (_arena != nullptr) {
        calloc.free(_arena);
      }
      _arena = calloc<Uint8>(byteBudget);
      _arenaCapacity = byteBudget;
    }
    _arenaOffset = 0;
  }

  Pointer<Uint8> _arenaAlloc(int bytes) {
    // Keep every array 8-byte aligned (doubles).
    final aligned = (_arenaOffset + 7) & ~7;
    _arenaOffset = aligned + bytes;
    assert(_arenaOffset <= _arenaCapacity);
    return Pointer<Uint8>.fromAddress(_arena.address + aligned);
  }

  Pointer<Double> _arenaFloat64(Float64List data) {
    final pointer = _arenaAlloc(data.length * 8).cast<Double>();
    pointer.asTypedList(data.length).setAll(0, data);
    return pointer;
  }

  Pointer<Int32> _arenaInt32(Int32List data) {
    final pointer = _arenaAlloc(data.length * 4).cast<Int32>();
    pointer.asTypedList(data.length).setAll(0, data);
    return pointer;
  }

  Pointer<Uint8> _arenaUint8(Uint8List data) {
    final pointer = _arenaAlloc(data.length);
    pointer.asTypedList(data.length).setAll(0, data);
    return pointer;
  }

  static const int dabFlagErase = 1;
  static const int dabFlagRound = 2;
  static const int dabFlagEllipse = 4;
  static const int dabFlagRotatedRect = 8;
  static const int dabFlagTipUnrotated = 16;

  /// Per-dab setup for [dabBlendTile]: fills the spec struct and uploads
  /// masks (identity-cached) and lattices (arena). All values mirror the
  /// Dart materializer's per-dab hoists exactly; the kernel is a pure
  /// consumer.
  void prepareDab({
    required double centerX,
    required double centerY,
    required double radius,
    required double hardRadius,
    required double edgeSpan,
    required double minorRadius,
    required double tipCos,
    required double tipSin,
    required double inverseRoundness,
    required double dabOpacity,
    required double dabFlow,
    required double sourceAlphaNorm,
    required double radiusSqSkip,
    required double textureDensity,
    required double textureOneMinusDensity,
    required int sourceR,
    required int sourceG,
    required int sourceB,
    required int flags,
    required int regionLeft,
    required int regionTop,
    Float64List? tipAlpha,
    int tipSize = 0,
    Int32List? tipUTexel0,
    Float64List? tipUFraction,
    Float64List? tipUOneMinus,
    Uint8List? tipUInRange,
    Int32List? tipVTexel0,
    Float64List? tipVFraction,
    Float64List? tipVOneMinus,
    Uint8List? tipVInRange,
    Float64List? dualAlpha,
    int dualSize = 0,
    Int32List? dualUTexel0,
    Int32List? dualUTexel1,
    Float64List? dualUFraction,
    Float64List? dualUOneMinus,
    Int32List? dualVTexel0,
    Int32List? dualVTexel1,
    Float64List? dualVFraction,
    Float64List? dualVOneMinus,
    Float64List? texAlpha,
    int texSize = 0,
    Int32List? texUTexel0,
    Int32List? texUTexel1,
    Float64List? texUFraction,
    Float64List? texUOneMinus,
    Int32List? texVTexel0,
    Int32List? texVTexel1,
    Float64List? texVFraction,
    Float64List? texVOneMinus,
  }) {
    var budget = 0;
    void count(TypedData? data) {
      if (data != null) {
        budget += data.lengthInBytes + 8;
      }
    }

    count(tipUTexel0);
    count(tipUFraction);
    count(tipUOneMinus);
    count(tipUInRange);
    count(tipVTexel0);
    count(tipVFraction);
    count(tipVOneMinus);
    count(tipVInRange);
    count(dualUTexel0);
    count(dualUTexel1);
    count(dualUFraction);
    count(dualUOneMinus);
    count(dualVTexel0);
    count(dualVTexel1);
    count(dualVFraction);
    count(dualVOneMinus);
    count(texUTexel0);
    count(texUTexel1);
    count(texUFraction);
    count(texUOneMinus);
    count(texVTexel0);
    count(texVTexel1);
    count(texVFraction);
    count(texVOneMinus);
    _arenaReset(budget);

    final spec = _spec.ref;
    spec.centerX = centerX;
    spec.centerY = centerY;
    spec.radius = radius;
    spec.hardRadius = hardRadius;
    spec.edgeSpan = edgeSpan;
    spec.minorRadius = minorRadius;
    spec.tipCos = tipCos;
    spec.tipSin = tipSin;
    spec.inverseRoundness = inverseRoundness;
    spec.dabOpacity = dabOpacity;
    spec.dabFlow = dabFlow;
    spec.sourceAlphaNorm = sourceAlphaNorm;
    spec.radiusSqSkip = radiusSqSkip;
    spec.textureDensity = textureDensity;
    spec.textureOneMinusDensity = textureOneMinusDensity;
    spec.sourceR = sourceR;
    spec.sourceG = sourceG;
    spec.sourceB = sourceB;
    spec.flags = flags;
    spec.regionLeft = regionLeft;
    spec.regionTop = regionTop;
    spec.tipSize = tipSize;
    spec.dualSize = dualSize;
    spec.texSize = texSize;
    spec.reserved = 0;
    spec.tipAlpha = tipAlpha == null ? nullptr : _uploadMask(tipAlpha);
    spec.tipUTexel0 = tipUTexel0 == null ? nullptr : _arenaInt32(tipUTexel0);
    spec.tipUFraction = tipUFraction == null
        ? nullptr
        : _arenaFloat64(tipUFraction);
    spec.tipUOneMinus = tipUOneMinus == null
        ? nullptr
        : _arenaFloat64(tipUOneMinus);
    spec.tipUInRange = tipUInRange == null ? nullptr : _arenaUint8(tipUInRange);
    spec.tipVTexel0 = tipVTexel0 == null ? nullptr : _arenaInt32(tipVTexel0);
    spec.tipVFraction = tipVFraction == null
        ? nullptr
        : _arenaFloat64(tipVFraction);
    spec.tipVOneMinus = tipVOneMinus == null
        ? nullptr
        : _arenaFloat64(tipVOneMinus);
    spec.tipVInRange = tipVInRange == null ? nullptr : _arenaUint8(tipVInRange);
    spec.dualAlpha = dualAlpha == null ? nullptr : _uploadMask(dualAlpha);
    spec.dualUTexel0 = dualUTexel0 == null ? nullptr : _arenaInt32(dualUTexel0);
    spec.dualUTexel1 = dualUTexel1 == null ? nullptr : _arenaInt32(dualUTexel1);
    spec.dualUFraction = dualUFraction == null
        ? nullptr
        : _arenaFloat64(dualUFraction);
    spec.dualUOneMinus = dualUOneMinus == null
        ? nullptr
        : _arenaFloat64(dualUOneMinus);
    spec.dualVTexel0 = dualVTexel0 == null ? nullptr : _arenaInt32(dualVTexel0);
    spec.dualVTexel1 = dualVTexel1 == null ? nullptr : _arenaInt32(dualVTexel1);
    spec.dualVFraction = dualVFraction == null
        ? nullptr
        : _arenaFloat64(dualVFraction);
    spec.dualVOneMinus = dualVOneMinus == null
        ? nullptr
        : _arenaFloat64(dualVOneMinus);
    spec.texAlpha = texAlpha == null ? nullptr : _uploadMask(texAlpha);
    spec.texUTexel0 = texUTexel0 == null ? nullptr : _arenaInt32(texUTexel0);
    spec.texUTexel1 = texUTexel1 == null ? nullptr : _arenaInt32(texUTexel1);
    spec.texUFraction = texUFraction == null
        ? nullptr
        : _arenaFloat64(texUFraction);
    spec.texUOneMinus = texUOneMinus == null
        ? nullptr
        : _arenaFloat64(texUOneMinus);
    spec.texVTexel0 = texVTexel0 == null ? nullptr : _arenaInt32(texVTexel0);
    spec.texVTexel1 = texVTexel1 == null ? nullptr : _arenaInt32(texVTexel1);
    spec.texVFraction = texVFraction == null
        ? nullptr
        : _arenaFloat64(texVFraction);
    spec.texVOneMinus = texVOneMinus == null
        ? nullptr
        : _arenaFloat64(texVOneMinus);
  }
}

/// A pooled native tile buffer: the raw pointer for the kernel and a
/// typed-data view over the SAME memory for Dart-side reads/writes.
class QaNativeTileBuffer {
  QaNativeTileBuffer._(this.pointer, this.view);

  final Pointer<Uint8> pointer;
  final Uint8List view;
}

/// The lazy fill raster's shared native buffers (R18 A-2b): the raster
/// composes pixels into [rgbView] and marks compose tiles in
/// [composedView]; the C flood stepper reads both through the SAME
/// memory. Valid for one fill (the engine reuses the buffers on the next
/// [QaNativeEngine.acquireFloodRaster]).
class QaFloodNativeHandles {
  QaFloodNativeHandles._({
    required this.rgbView,
    required this.composedView,
    required this.width,
    required this.height,
    required this.tilesX,
    required this.composeTileShift,
  });

  /// `width*height*3` straight-RGB bytes; only composed tiles are ever
  /// read, so uncomposed regions may hold stale bytes.
  final Uint8List rgbView;

  /// One byte per compose tile (row-major, `tilesX` wide): nonzero once
  /// the raster composed that tile. Zeroed at acquire.
  final Uint8List composedView;

  final int width;
  final int height;
  final int tilesX;
  final int composeTileShift;
}

/// Mirror of the C `qa_tile_span` — field order/types must match EXACTLY
/// (the loader cross-checks sizeof on both sides before enabling the
/// native path).
final class QaTileSpanStruct extends Struct {
  external Pointer<Uint8> tilePixels;
  @Int32()
  external int tileLeft;
  @Int32()
  external int tileTop;
  @Int32()
  external int spanLeft;
  @Int32()
  external int spanRightExclusive;
  @Int32()
  external int spanTop;
  @Int32()
  external int spanBottomExclusive;
  @Int32()
  external int reserved;
}

/// Mirror of the C `qa_dab_spec` — field order/types must match EXACTLY
/// (the loader cross-checks sizeof on both sides before enabling the
/// native path).
final class QaDabSpecStruct extends Struct {
  @Double()
  external double centerX;
  @Double()
  external double centerY;
  @Double()
  external double radius;
  @Double()
  external double hardRadius;
  @Double()
  external double edgeSpan;
  @Double()
  external double minorRadius;
  @Double()
  external double tipCos;
  @Double()
  external double tipSin;
  @Double()
  external double inverseRoundness;
  @Double()
  external double dabOpacity;
  @Double()
  external double dabFlow;
  @Double()
  external double sourceAlphaNorm;
  @Double()
  external double radiusSqSkip;
  @Double()
  external double textureDensity;
  @Double()
  external double textureOneMinusDensity;
  @Int32()
  external int sourceR;
  @Int32()
  external int sourceG;
  @Int32()
  external int sourceB;
  @Int32()
  external int flags;
  @Int32()
  external int regionLeft;
  @Int32()
  external int regionTop;
  @Int32()
  external int tipSize;
  @Int32()
  external int dualSize;
  @Int32()
  external int texSize;
  @Int32()
  external int reserved;
  external Pointer<Double> tipAlpha;
  external Pointer<Int32> tipUTexel0;
  external Pointer<Double> tipUFraction;
  external Pointer<Double> tipUOneMinus;
  external Pointer<Uint8> tipUInRange;
  external Pointer<Int32> tipVTexel0;
  external Pointer<Double> tipVFraction;
  external Pointer<Double> tipVOneMinus;
  external Pointer<Uint8> tipVInRange;
  external Pointer<Double> dualAlpha;
  external Pointer<Int32> dualUTexel0;
  external Pointer<Int32> dualUTexel1;
  external Pointer<Double> dualUFraction;
  external Pointer<Double> dualUOneMinus;
  external Pointer<Int32> dualVTexel0;
  external Pointer<Int32> dualVTexel1;
  external Pointer<Double> dualVFraction;
  external Pointer<Double> dualVOneMinus;
  external Pointer<Double> texAlpha;
  external Pointer<Int32> texUTexel0;
  external Pointer<Int32> texUTexel1;
  external Pointer<Double> texUFraction;
  external Pointer<Double> texUOneMinus;
  external Pointer<Int32> texVTexel0;
  external Pointer<Int32> texVTexel1;
  external Pointer<Double> texVFraction;
  external Pointer<Double> texVOneMinus;
}
