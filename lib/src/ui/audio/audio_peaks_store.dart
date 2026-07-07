import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/audio/audio_peaks_extractor.dart';

/// Session-level cache of waveform peaks per audio file path, mirroring
/// the storyboard thumbnail store's shape: [peaksFor] resolves
/// synchronously (null while absent) and kicks ONE async extraction per
/// path; listeners are notified when a result lands. Failed extractions
/// (missing ffmpeg, undecodable file) are remembered so they don't retry
/// in a loop — re-importing the file starts fresh via [invalidate].
class AudioPeaksStore extends ChangeNotifier {
  AudioPeaksStore({AudioPeaksExtractor? extractor})
    : _extractor = extractor ?? const AudioPeaksExtractor();

  final AudioPeaksExtractor _extractor;
  final Map<String, AudioPeaks> _peaks = {};
  final Set<String> _extracting = {};
  final Set<String> _failed = {};
  bool _disposed = false;

  AudioPeaks? peaksFor(String filePath) {
    final cached = _peaks[filePath];
    if (cached != null) {
      return cached;
    }
    if (!_extracting.contains(filePath) && !_failed.contains(filePath)) {
      _extracting.add(filePath);
      unawaited(_extract(filePath));
    }
    return null;
  }

  Future<void> _extract(String filePath) async {
    AudioPeaks? peaks;
    try {
      peaks = await _extractor.extract(filePath);
    } catch (_) {
      peaks = null;
    }
    if (_disposed) {
      return;
    }
    _extracting.remove(filePath);
    if (peaks == null) {
      _failed.add(filePath);
    } else {
      _peaks[filePath] = peaks;
    }
    notifyListeners();
  }

  /// Forgets a path (e.g. the file changed on disk) so the next
  /// [peaksFor] extracts again.
  void invalidate(String filePath) {
    _peaks.remove(filePath);
    _failed.remove(filePath);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
