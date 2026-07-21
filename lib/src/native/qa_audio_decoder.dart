import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Which decoder read a file — reported so a log can say what happened
/// instead of just "it worked". [os] is the platform's own codec stack
/// (Media Foundation / AudioToolbox / MediaCodec), reached only for
/// containers dr_libs does not read — AAC/m4a per the decided format
/// table.
enum QaAudioFormat { unknown, wav, flac, mp3, os }

/// A decoded audio file, at the file's OWN sample rate.
///
/// Resampling to the project rate is deliberately NOT done here: it is a
/// quality decision (what filter, what rolloff) and hiding it inside a
/// decode call would make it invisible.
class QaDecodedAudio {
  const QaDecodedAudio({
    required this.samples,
    required this.channels,
    required this.sampleRate,
    required this.format,
  });

  /// Interleaved by channel, normalized to [-1, 1].
  final Float32List samples;
  final int channels;
  final int sampleRate;
  final QaAudioFormat format;

  /// Samples per channel.
  int get length => channels <= 0 ? 0 : samples.length ~/ channels;
}

/// Decodes WAV / FLAC / MP3 through the vendored dr_libs in the native
/// core.
///
/// Decoding runs ONCE at import — that is what conforming means, and why a
/// variable-length codec never has to finish inside an audio callback.
///
/// The bytes are read on the Dart side and handed over as MEMORY, never as
/// a path: Dart already opens files correctly on every platform, whereas a
/// `const char*` would drag in the question of whether a Windows path is
/// UTF-8 or the local codepage — and a Korean filename would settle it the
/// hard way.
final class QaAudioDecoder {
  QaAudioDecoder._(this._decode, this._free);

  final int Function(
    Pointer<Uint8>,
    int,
    Pointer<Pointer<Float>>,
    Pointer<Int64>,
    Pointer<Int32>,
    Pointer<Int32>,
  )
  _decode;
  final void Function(Pointer<Float>) _free;

  static QaAudioDecoder? _instance;
  static bool _tried = false;

  /// Test hook: point the loader at a locally built binary.
  static String? debugLibraryPathOverride;

  static void debugResetForTests() {
    _instance = null;
    _tried = false;
  }

  /// The native decoder, or null when no binary is available.
  static QaAudioDecoder? get instance {
    if (!_tried) {
      _tried = true;
      _instance = _load();
    }
    return _instance;
  }

  static QaAudioDecoder? _load() {
    final library = _tryOpen();
    if (library == null) {
      return null;
    }
    try {
      return QaAudioDecoder._(
        library.lookupFunction<
          Int32 Function(
            Pointer<Uint8>,
            Int64,
            Pointer<Pointer<Float>>,
            Pointer<Int64>,
            Pointer<Int32>,
            Pointer<Int32>,
          ),
          int Function(
            Pointer<Uint8>,
            int,
            Pointer<Pointer<Float>>,
            Pointer<Int64>,
            Pointer<Int32>,
            Pointer<Int32>,
          )
        >('qa_audio_decode_memory'),
        library.lookupFunction<
          Void Function(Pointer<Float>),
          void Function(Pointer<Float>)
        >('qa_audio_decode_free'),
      );
    } on Object {
      return null;
    }
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
        // Fall through: a standalone dylib build is still honored below.
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

  /// Decodes [bytes]; null when no decoder recognized the container.
  QaDecodedAudio? decode(Uint8List bytes) {
    if (bytes.isEmpty) {
      return null;
    }
    final data = calloc<Uint8>(bytes.length);
    final samplesOut = calloc<Pointer<Float>>();
    final frameCountOut = calloc<Int64>();
    final channelsOut = calloc<Int32>();
    final sampleRateOut = calloc<Int32>();
    try {
      data.asTypedList(bytes.length).setAll(0, bytes);
      final format = _decode(
        data,
        bytes.length,
        samplesOut,
        frameCountOut,
        channelsOut,
        sampleRateOut,
      );
      final samples = samplesOut.value;
      if (format == 0 || samples == nullptr) {
        return null;
      }
      try {
        final channels = channelsOut.value;
        final frames = frameCountOut.value;
        final total = frames * channels;
        // Copy out of native memory before freeing it — the decoder owns
        // that block, and a Dart view over it would dangle.
        final copied = Float32List(total < 0 ? 0 : total);
        if (total > 0) {
          copied.setAll(0, samples.asTypedList(total));
        }
        return QaDecodedAudio(
          samples: copied,
          channels: channels,
          sampleRate: sampleRateOut.value,
          format: format >= 1 && format <= 4
              ? QaAudioFormat.values[format]
              : QaAudioFormat.unknown,
        );
      } finally {
        _free(samples);
      }
    } finally {
      calloc.free(sampleRateOut);
      calloc.free(channelsOut);
      calloc.free(frameCountOut);
      calloc.free(samplesOut);
      calloc.free(data);
    }
  }
}
