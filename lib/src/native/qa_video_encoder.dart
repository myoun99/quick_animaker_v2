import 'dart:convert' show utf8;
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// The OS video encoder (AUDIO-PRO R7): frames + mixed PCM in, an
/// H.264/AAC MP4 out through the operating system's own codec stack —
/// Media Foundation on Windows, AVAssetWriter on Apple, NDK MediaCodec on
/// Android. No ffmpeg.
///
/// Absence is graceful: no binary, or a platform with no OS encoder
/// (Linux), leaves [isSupported] false and the caller on the ffmpeg
/// fallback — chosen, not crashed into.
final class QaVideoEncoder {
  QaVideoEncoder._(this._library);

  final DynamicLibrary _library;

  static QaVideoEncoder? _instance;
  static bool _tried = false;

  /// Test hook: point the loader at a locally built binary.
  static String? debugLibraryPathOverride;

  static void debugResetForTests() {
    _instance = null;
    _tried = false;
  }

  static QaVideoEncoder? get instance {
    if (!_tried) {
      _tried = true;
      final library = _tryOpen();
      _instance = library == null ? null : QaVideoEncoder._(library);
    }
    return _instance;
  }

  static DynamicLibrary? _tryOpen() {
    final overridePath =
        debugLibraryPathOverride ?? Platform.environment['QA_ENGINE_PATH'];
    if (overridePath != null && overridePath.isNotEmpty) {
      try {
        return DynamicLibrary.open(overridePath);
      } on Object {
        // Fall through to the platform defaults.
      }
    }
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        return DynamicLibrary.process();
      } on Object {
        // Fall through.
      }
    }
    for (final candidate in [
      if (Platform.isWindows) 'qa_engine.dll',
      if (Platform.isLinux || Platform.isAndroid) 'libqa_engine.so',
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

  late final _supported = _library
      .lookupFunction<Int32 Function(), int Function()>(
        'qa_video_export_supported',
      );
  late final _open = _library
      .lookupFunction<
        Int32 Function(
          Pointer<Utf8>,
          Int32,
          Int32,
          Int32,
          Int32,
          Int32,
          Int32,
        ),
        int Function(Pointer<Utf8>, int, int, int, int, int, int)
      >('qa_video_export_open');
  late final _writeFrame = _library
      .lookupFunction<
        Int32 Function(Pointer<Uint8>),
        int Function(Pointer<Uint8>)
      >('qa_video_export_write_frame');
  late final _writeAudio = _library
      .lookupFunction<
        Int32 Function(Pointer<Int16>, Int32),
        int Function(Pointer<Int16>, int)
      >('qa_video_export_write_audio');
  late final _finish = _library
      .lookupFunction<Int32 Function(), int Function()>(
        'qa_video_export_finish',
      );
  late final _abort = _library
      .lookupFunction<Void Function(), void Function()>(
        'qa_video_export_abort',
      );
  late final _error = _library
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Int32),
        int Function(Pointer<Utf8>, int)
      >('qa_video_export_error');

  /// Whether THIS build and OS can encode (Android answers by actually
  /// resolving the NDK media symbols).
  bool get isSupported {
    try {
      return _supported() != 0;
    } on Object {
      return false; // an older binary without the export surface
    }
  }

  /// Opens an MP4 at [path]. [channels] 0 = silent video. Returns false
  /// with [lastError] readable on any refusal.
  bool open({
    required String path,
    required int width,
    required int height,
    required int fpsNumerator,
    required int fpsDenominator,
    int sampleRate = 0,
    int channels = 0,
  }) {
    final pathUtf8 = path.toNativeUtf8();
    try {
      return _open(
            pathUtf8,
            width,
            height,
            fpsNumerator,
            fpsDenominator,
            sampleRate,
            channels,
          ) !=
          0;
    } finally {
      calloc.free(pathUtf8);
    }
  }

  /// Writes one top-down RGBA frame (exactly the renderer's rawRgba).
  bool writeFrame(Uint8List rgba) {
    final buffer = calloc<Uint8>(rgba.length);
    try {
      buffer.asTypedList(rgba.length).setAll(0, rgba);
      return _writeFrame(buffer) != 0;
    } finally {
      calloc.free(buffer);
    }
  }

  /// Writes interleaved int16 PCM ([frames] per channel) — call in chunks
  /// alongside the frames so neither side buffers the whole track.
  bool writeAudio(Int16List interleaved, int frames) {
    final buffer = calloc<Int16>(interleaved.length);
    try {
      buffer.asTypedList(interleaved.length).setAll(0, interleaved);
      return _writeAudio(buffer, frames) != 0;
    } finally {
      calloc.free(buffer);
    }
  }

  /// Finalizes the MP4 — a cancelled run finalizes a playable partial,
  /// matching the ffmpeg path's behavior.
  bool finish() => _finish() != 0;

  /// Discards an export that failed partway.
  void abort() => _abort();

  /// The last failure, for the export dialog to show verbatim.
  String get lastError {
    final buffer = calloc<Uint8>(256);
    try {
      final length = _error(buffer.cast<Utf8>(), 256);
      if (length <= 0) {
        return '';
      }
      return utf8.decode(buffer.asTypedList(length));
    } finally {
      calloc.free(buffer);
    }
  }
}
