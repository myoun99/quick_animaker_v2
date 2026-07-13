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
  QaNativeEngine._(this._stampBlendRow);

  static const int _abiVersion = 1;

  final int Function(
    Pointer<Uint8> tileRow,
    Pointer<Uint8> stampRow,
    int count,
    double opacity,
    int erase,
  )
  _stampBlendRow;

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
      final stampBlendRow = library
          .lookupFunction<
            Int32 Function(Pointer<Uint8>, Pointer<Uint8>, Int32, Double, Int32),
            int Function(Pointer<Uint8>, Pointer<Uint8>, int, double, int)
          >('qa_stamp_blend_row');
      return QaNativeEngine._(stampBlendRow);
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
}
