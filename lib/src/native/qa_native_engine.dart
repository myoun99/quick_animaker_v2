import 'dart:collection';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'dart:typed_data';

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
  QaNativeEngine._(this._stampBlendRow, this._dabBlendTile)
    : _spec = calloc<QaDabSpecStruct>();

  static const int _abiVersion = 2;

  final int Function(
    Pointer<Uint8> tileRow,
    Pointer<Uint8> stampRow,
    int count,
    double opacity,
    int erase,
  )
  _stampBlendRow;

  final int Function(
    Pointer<Uint8> tilePixels,
    int tileSize,
    int tileLeft,
    int tileTop,
    int spanLeft,
    int spanRightExclusive,
    int spanTop,
    int spanBottomExclusive,
    Pointer<QaDabSpecStruct> spec,
  )
  _dabBlendTile;

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
      final stampBlendRow = library
          .lookupFunction<
            Int32 Function(
              Pointer<Uint8>,
              Pointer<Uint8>,
              Int32,
              Double,
              Int32,
            ),
            int Function(Pointer<Uint8>, Pointer<Uint8>, int, double, int)
          >('qa_stamp_blend_row');
      final dabBlendTile = library
          .lookupFunction<
            Int32 Function(
              Pointer<Uint8>,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Pointer<QaDabSpecStruct>,
            ),
            int Function(
              Pointer<Uint8>,
              int,
              int,
              int,
              int,
              int,
              int,
              int,
              Pointer<QaDabSpecStruct>,
            )
          >('qa_dab_blend_tile');
      return QaNativeEngine._(stampBlendRow, dabBlendTile);
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

  /// Scratch native buffers reused across calls (grown on demand) — the
  /// copy-in/copy-out phase-0 shape; the zero-copy native-buffer
  /// migration (A-1.5) retires these.
  Pointer<Uint8> _tileScratch = nullptr;
  int _tileScratchLength = 0;
  Pointer<Uint8> _stampScratch = nullptr;
  int _stampScratchLength = 0;

  Pointer<Uint8> _ensureTileScratch(int length) {
    if (_tileScratchLength < length) {
      if (_tileScratch != nullptr) {
        calloc.free(_tileScratch);
      }
      _tileScratch = calloc<Uint8>(length);
      _tileScratchLength = length;
    }
    return _tileScratch;
  }

  Pointer<Uint8> _ensureStampScratch(int length) {
    if (_stampScratchLength < length) {
      if (_stampScratch != nullptr) {
        calloc.free(_stampScratch);
      }
      _stampScratch = calloc<Uint8>(length);
      _stampScratchLength = length;
    }
    return _stampScratch;
  }

  /// Blends a stamp row span into [tileRow] (straight-alpha RGBA, 4 bytes
  /// per pixel on both sides) — byte-identical to the Dart stamp path.
  /// Returns true when any destination byte changed.
  bool stampBlendRow({
    required Uint8List tileRow,
    required int tileOffset,
    required Uint8List stampRow,
    required int stampOffset,
    required int count,
    required double opacity,
    required bool erase,
  }) {
    final byteCount = count * 4;
    final tilePointer = _ensureTileScratch(byteCount);
    final stampPointer = _ensureStampScratch(byteCount);
    tilePointer
        .asTypedList(byteCount)
        .setRange(0, byteCount, tileRow, tileOffset);
    stampPointer
        .asTypedList(byteCount)
        .setRange(0, byteCount, stampRow, stampOffset);
    final changed = _stampBlendRow(
      tilePointer,
      stampPointer,
      count,
      opacity,
      erase ? 1 : 0,
    );
    if (changed != 0) {
      tileRow.setRange(
        tileOffset,
        tileOffset + byteCount,
        tilePointer.asTypedList(byteCount),
      );
      return true;
    }
    return false;
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
  static const int _tilePoolCapPerLength = 32;

  /// A pooled buffer; [zeroed] skips the memset when the caller overwrites
  /// every byte anyway (existing-tile copy-in).
  QaNativeTileBuffer acquireTileBuffer(int byteLength, {required bool zeroed}) {
    final pool = _tilePool[byteLength];
    if (pool != null && pool.isNotEmpty) {
      final buffer = pool.removeLast();
      if (zeroed) {
        buffer.view.fillRange(0, byteLength, 0);
      }
      return buffer;
    }
    final pointer = calloc<Uint8>(byteLength);
    return QaNativeTileBuffer._(pointer, pointer.asTypedList(byteLength));
  }

  void releaseTileBuffer(QaNativeTileBuffer buffer) {
    final pool = _tilePool.putIfAbsent(buffer.view.length, () => []);
    if (pool.length >= _tilePoolCapPerLength) {
      calloc.free(buffer.pointer);
      return;
    }
    pool.add(buffer);
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

  /// Blends the prepared dab ([prepareDab]) into one native tile buffer
  /// over the given canvas-space spans — byte-identical to the Dart
  /// generic loop. Returns true when any destination byte changed.
  bool dabBlendTile({
    required Pointer<Uint8> tilePixels,
    required int tileSize,
    required int tileLeft,
    required int tileTop,
    required int spanLeft,
    required int spanRightExclusive,
    required int spanTop,
    required int spanBottomExclusive,
  }) {
    return _dabBlendTile(
          tilePixels,
          tileSize,
          tileLeft,
          tileTop,
          spanLeft,
          spanRightExclusive,
          spanTop,
          spanBottomExclusive,
          _spec,
        ) !=
        0;
  }
}

/// A pooled native tile buffer: the raw pointer for the kernel and a
/// typed-data view over the SAME memory for Dart-side reads/writes.
class QaNativeTileBuffer {
  QaNativeTileBuffer._(this.pointer, this.view);

  final Pointer<Uint8> pointer;
  final Uint8List view;
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
