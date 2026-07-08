import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/audio/audio_peaks_extractor.dart';

class _PeaksFailure {
  const _PeaksFailure({
    required this.reason,
    required this.attempts,
    required this.lastAttemptAt,
  });

  final String reason;
  final int attempts;
  final DateTime lastAttemptAt;
}

/// Session-level cache of waveform peaks per audio file path, mirroring
/// the storyboard thumbnail store's shape: [peaksFor] resolves
/// synchronously (null while absent) and kicks ONE async extraction per
/// path; listeners are notified when a result lands.
///
/// Failures are never silent: each one is logged with the extractor's
/// reason (missing ffmpeg, decode error with stderr) and remembered in
/// [failureFor]. A failed path retries on a later [peaksFor] once
/// [retryDelay] has passed, up to [maxAttempts] — transient failures
/// (file still being written, first-run probe) self-heal, while a hard
/// failure can't spin the paint loop. [invalidate] (re-import) or
/// [retryFailures] start fresh.
class AudioPeaksStore extends ChangeNotifier {
  AudioPeaksStore({
    AudioPeaksExtractor? extractor,
    DateTime Function()? now,
    this.maxAttempts = 3,
    this.retryDelay = const Duration(seconds: 2),
    void Function(String message)? log,
  }) : _extractor = extractor ?? const AudioPeaksExtractor(),
       _now = now ?? DateTime.now,
       _log = log ?? debugPrint;

  final AudioPeaksExtractor _extractor;
  final DateTime Function() _now;
  final void Function(String message) _log;
  final int maxAttempts;
  final Duration retryDelay;

  final Map<String, AudioPeaks> _peaks = {};
  final Set<String> _extracting = {};
  final Map<String, _PeaksFailure> _failures = {};
  bool _disposed = false;

  AudioPeaks? peaksFor(String filePath) {
    final cached = _peaks[filePath];
    if (cached != null) {
      return cached;
    }
    if (_extracting.contains(filePath)) {
      return null;
    }
    final failure = _failures[filePath];
    if (failure != null &&
        (failure.attempts >= maxAttempts ||
            _now().difference(failure.lastAttemptAt) < retryDelay)) {
      return null;
    }
    _extracting.add(filePath);
    unawaited(_extract(filePath));
    return null;
  }

  /// The last extraction failure reason for [filePath], or null while the
  /// path is unknown, pending or successfully extracted.
  String? failureFor(String filePath) => _failures[filePath]?.reason;

  Future<void> _extract(String filePath) async {
    AudioPeaksExtraction result;
    try {
      result = await _extractor.extract(filePath);
    } catch (error) {
      result = AudioPeaksExtraction.failure('unexpected error: $error');
    }
    if (_disposed) {
      return;
    }
    _extracting.remove(filePath);
    final peaks = result.peaks;
    if (peaks == null) {
      final attempts = (_failures[filePath]?.attempts ?? 0) + 1;
      _failures[filePath] = _PeaksFailure(
        reason: result.error ?? 'unknown failure',
        attempts: attempts,
        lastAttemptAt: _now(),
      );
      _log(
        '[AudioPeaksStore] waveform extraction failed '
        '(attempt $attempts/$maxAttempts) for $filePath: ${result.error}',
      );
    } else {
      _failures.remove(filePath);
      _peaks[filePath] = peaks;
    }
    notifyListeners();
  }

  /// Forgets a path (re-import, the file changed on disk) so the next
  /// [peaksFor] extracts again with a fresh attempt budget.
  void invalidate(String filePath) {
    _peaks.remove(filePath);
    _failures.remove(filePath);
  }

  /// Clears every remembered failure so the next paint retries them (e.g.
  /// after the user installs ffmpeg).
  void retryFailures() {
    if (_failures.isEmpty) {
      return;
    }
    _failures.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
