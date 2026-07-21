/// Runs one conform off the UI thread (audio program wiring).
///
/// Decoding and resampling a file is seconds of CPU on minutes of audio —
/// running it on the UI isolate would freeze the canvas exactly when the
/// user just imported a sound and wants to keep drawing. `Isolate.run`
/// moves the whole pipeline to a worker; the request is plain values, the
/// result crosses back as one copy.
///
/// The native singletons resolve PER ISOLATE (a `DynamicLibrary` is opened
/// wherever it is first asked for), which is why the entry point builds
/// the pipeline inside the isolate instead of capturing one.
library;

import 'dart:isolate';

import '../../native/qa_audio_decoder.dart';
import '../../native/qa_audio_native.dart';
import 'audio_conform_pipeline.dart';
import 'audio_resampler_reference.dart';

/// One conform request — every field a sendable value so the whole thing
/// can cross an isolate boundary.
class ConformRequest {
  const ConformRequest({
    required this.sourcePath,
    required this.conformPath,
    this.projectSampleRate = 48000,
    this.bucketsPerSecond = 80,
    this.libraryPathOverride,
  });

  final String sourcePath;

  /// Null = memory-only (the unsaved-project case; see
  /// [AudioConformPipeline.ensureConform]).
  final String? conformPath;

  final int projectSampleRate;
  final int bucketsPerSecond;

  /// Test hook: the worker isolate starts with fresh statics, so a test
  /// pointing the loaders at a locally built binary has to send the path
  /// along rather than rely on having set it on the main isolate.
  final String? libraryPathOverride;
}

/// How a store runs a conform; production is [runConformInIsolate], tests
/// substitute a synchronous fake.
typedef ConformRunner = Future<ConformResult> Function(ConformRequest request);

/// The production runner.
Future<ConformResult> runConformInIsolate(ConformRequest request) =>
    Isolate.run(() => runConformHere(request));

/// The pipeline itself, on whichever isolate this is called from —
/// [runConformInIsolate]'s worker body, and directly callable by tests
/// that want the real native path without isolate indirection.
ConformResult runConformHere(ConformRequest request) {
  final override = request.libraryPathOverride;
  if (override != null) {
    QaAudioDecoder.debugLibraryPathOverride = override;
    QaAudioNative.debugLibraryPathOverride = override;
  }
  final pipeline = AudioConformPipeline(
    decode: (bytes) {
      final decoded = QaAudioDecoder.instance?.decode(bytes);
      if (decoded == null) {
        return null;
      }
      return (
        samples: decoded.samples,
        channels: decoded.channels,
        sampleRate: decoded.sampleRate,
      );
    },
    // Native resampler when the binary is present; the byte-identical Dart
    // reference otherwise. Either way the SAME filter design — that is what
    // the parity pins are for.
    resample:
        ({
          required samples,
          required channels,
          required inputRate,
          required outputRate,
        }) {
          final native = QaAudioNative.instance;
          if (native != null) {
            return native.resample(
              samples: samples,
              channels: channels,
              inputRate: inputRate,
              outputRate: outputRate,
            );
          }
          return resampleAudioReference(
            samples: samples,
            channels: channels,
            inputRate: inputRate,
            outputRate: outputRate,
          ).samples;
        },
    projectSampleRate: request.projectSampleRate,
    bucketsPerSecond: request.bucketsPerSecond,
  );
  return pipeline.ensureConform(
    sourcePath: request.sourcePath,
    conformPath: request.conformPath,
  );
}
