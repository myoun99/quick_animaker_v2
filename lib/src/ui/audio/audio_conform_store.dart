import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/audio/audio_conform_pipeline.dart';
import '../../services/audio/audio_conform_runner.dart';
import '../../services/audio/audio_peaks_extractor.dart';
import 'audio_peaks_store.dart';

class _ConformFailure {
  const _ConformFailure({
    required this.reason,
    required this.attempts,
    required this.lastAttemptAt,
  });

  final String reason;
  final int attempts;
  final DateTime lastAttemptAt;
}

/// Session-level cache of CONFORMED audio per source path — the waveform's
/// peaks, the device transport's PCM, and the clip-length answer, all from
/// the same decode.
///
/// Shape mirrors [AudioPeaksStore]: [resultFor] resolves synchronously
/// (null while absent) and kicks ONE async conform per path; listeners are
/// notified when a result lands. Failures are remembered with the same
/// retry budget — transient ones (a file still syncing down from a cloud
/// folder) self-heal, and a hard one cannot spin the paint loop.
///
/// Formats the native decoder does not read (m4a/aac/ogg until the OS
/// decoders land) are a DEFINITIVE answer, not a failure: the entry stays,
/// and [peaksFor]/[durationSecondsFor] fall back to the ffmpeg extractor
/// for the waveform — per the decided format table (dr_libs is the single
/// realtime path; AAC rides the platform's decoder, which on desktop today
/// still means ffmpeg). Playback of those files stays on the platform
/// players; the routing is per FORMAT, so the same file never alternates
/// between paths.
class AudioConformStore extends ChangeNotifier {
  AudioConformStore({
    required this.resolveConformPath,
    ConformRunner? runner,
    AudioPeaksStore? undecodableFallback,
    this.projectSampleRate = 48000,
    this.bucketsPerSecond = 80,
    DateTime Function()? now,
    this.maxAttempts = 3,
    this.retryDelay = const Duration(seconds: 2),
    void Function(String message)? log,
    this.libraryPathOverride,
  }) : _runner = runner ?? runConformInIsolate,
       _undecodableFallback = undecodableFallback,
       _now = now ?? DateTime.now,
       _log = log ?? debugPrint;

  /// Where [sourcePath]'s conform lives, or null for memory-only (no
  /// project file yet). Injected rather than computed here because only
  /// the session knows the current `.qap` path.
  final String? Function(String sourcePath) resolveConformPath;

  final ConformRunner _runner;

  /// Carries the waveform for formats the native decoder cannot read.
  final AudioPeaksStore? _undecodableFallback;

  final int projectSampleRate;
  final int bucketsPerSecond;
  final DateTime Function() _now;
  final void Function(String message) _log;
  final int maxAttempts;
  final Duration retryDelay;

  /// Test hook, forwarded into every request (worker isolates start with
  /// fresh statics).
  final String? libraryPathOverride;

  final Map<String, ConformResult> _entries = {};
  final Set<String> _pending = {};
  final Map<String, _ConformFailure> _failures = {};
  bool _disposed = false;

  /// The conform for [sourcePath]: a usable result, a definitive
  /// `undecodable`, or null while pending/failed (kicking ONE async
  /// conform as a side effect, like [AudioPeaksStore.peaksFor]).
  ConformResult? resultFor(String sourcePath) {
    final cached = _entries[sourcePath];
    if (cached != null) {
      return cached;
    }
    if (_pending.contains(sourcePath)) {
      return null;
    }
    final failure = _failures[sourcePath];
    if (failure != null &&
        (failure.attempts >= maxAttempts ||
            _now().difference(failure.lastAttemptAt) < retryDelay)) {
      return null;
    }
    _pending.add(sourcePath);
    unawaited(_ensure(sourcePath));
    return null;
  }

  /// The waveform for [sourcePath] — conform-computed, or the ffmpeg
  /// fallback for formats the native decoder does not read.
  AudioPeaks? peaksFor(String sourcePath) {
    final entry = resultFor(sourcePath);
    if (entry == null) {
      return null;
    }
    if (entry.isUsable) {
      return entry.peaks;
    }
    if (entry.outcome == ConformOutcome.undecodable) {
      return _undecodableFallback?.peaksFor(sourcePath);
    }
    return null;
  }

  /// The clip length in seconds — an EXACT sample count over the rate for
  /// conformed files (the peaks-bucket approximation only for the ffmpeg
  /// fallback).
  double? durationSecondsFor(String sourcePath) {
    final entry = resultFor(sourcePath);
    if (entry == null) {
      return null;
    }
    if (entry.isUsable && entry.sampleRate > 0) {
      return entry.frames / entry.sampleRate;
    }
    if (entry.outcome == ConformOutcome.undecodable) {
      return _undecodableFallback?.peaksFor(sourcePath)?.durationSeconds;
    }
    return null;
  }

  /// The conformed PCM (interleaved float32 at [projectSampleRate]), or
  /// null while absent/unusable — what the device transport uploads.
  Float32List? samplesFor(String sourcePath) {
    final entry = resultFor(sourcePath);
    return entry != null && entry.isUsable ? entry.samples : null;
  }

  /// The last failure reason, or null while unknown/pending/usable.
  String? failureFor(String sourcePath) => _failures[sourcePath]?.reason;

  Future<void> _ensure(String sourcePath) async {
    ConformResult result;
    try {
      result = await _runner(
        ConformRequest(
          sourcePath: sourcePath,
          conformPath: resolveConformPath(sourcePath),
          projectSampleRate: projectSampleRate,
          bucketsPerSecond: bucketsPerSecond,
          libraryPathOverride: libraryPathOverride,
        ),
      );
    } catch (error) {
      result = ConformResult(
        outcome: ConformOutcome.writeFailed,
        error: 'unexpected error: $error',
      );
    }
    if (_disposed) {
      return;
    }
    _pending.remove(sourcePath);
    if (result.isUsable || result.outcome == ConformOutcome.undecodable) {
      // Undecodable is an ANSWER (route this format to the fallback), not
      // a retry candidate — the same bytes will not decode differently
      // next time.
      _failures.remove(sourcePath);
      _entries[sourcePath] = result;
    } else {
      final attempts = (_failures[sourcePath]?.attempts ?? 0) + 1;
      _failures[sourcePath] = _ConformFailure(
        reason: result.error ?? 'unknown failure',
        attempts: attempts,
        lastAttemptAt: _now(),
      );
      _log(
        '[AudioConformStore] conform failed '
        '(attempt $attempts/$maxAttempts) for $sourcePath: ${result.error}',
      );
    }
    notifyListeners();
  }

  /// Forgets a path (re-import, relink, the file changed on disk) so the
  /// next lookup conforms again with a fresh attempt budget.
  void invalidate(String sourcePath) {
    _entries.remove(sourcePath);
    _failures.remove(sourcePath);
    _undecodableFallback?.invalidate(sourcePath);
  }

  /// Kicks a conform for every path that has none yet — called on project
  /// open so waveforms and playback PCM are ready before the first play.
  void warmPaths(Iterable<String> sourcePaths) {
    for (final path in sourcePaths) {
      resultFor(path);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
