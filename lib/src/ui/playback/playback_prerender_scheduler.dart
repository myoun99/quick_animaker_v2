import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/playback_quality.dart';
import 'cut_frame_composite_cache.dart';

/// How much of the requested warm range is composited already.
@immutable
class PrerenderProgress {
  const PrerenderProgress({required this.cached, required this.total});

  static const none = PrerenderProgress(cached: 0, total: 0);

  final int cached;
  final int total;

  bool get isComplete => cached >= total;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrerenderProgress &&
          other.cached == cached &&
          other.total == total;

  @override
  int get hashCode => Object.hash(cached, total);

  @override
  String toString() => 'PrerenderProgress($cached/$total)';
}

/// Background composite warming (the AE RAM-preview green bar analogue).
///
/// One chunked async loop composites one frame per iteration and yields
/// between frames; it stays paused until [idleDelay] has elapsed since the
/// last [notifyEditActivity], so drawing never contends with warming. A new
/// warm request replaces the queue (generation counter cancellation).
class PlaybackPrerenderScheduler {
  PlaybackPrerenderScheduler({
    required this.composites,
    required this.resolveCut,
    this.afterFrameCached,
    this.idleDelay = const Duration(milliseconds: 400),
  });

  final CutFrameCompositeCache composites;
  final Cut? Function(CutId cutId) resolveCut;

  /// Called after each composited frame (budget enforcement hook).
  final void Function()? afterFrameCached;

  final Duration idleDelay;

  final ValueNotifier<PrerenderProgress> _progress = ValueNotifier(
    PrerenderProgress.none,
  );
  ValueListenable<PrerenderProgress> get progress => _progress;

  int _generation = 0;
  DateTime _lastActivity = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _current = Future<void>.value();
  bool _disposed = false;

  /// Completes when the current warm run has finished or been cancelled
  /// (test hook).
  Future<void> get idle => _current;

  /// Warms one cut, playhead-outward from [aroundFrameIndex].
  void requestWarmCut({
    required CutId cutId,
    required PlaybackQuality quality,
    int aroundFrameIndex = 0,
  }) {
    final cut = resolveCut(cutId);
    if (cut == null) {
      return;
    }
    final frameCount = math.max(1, cut.duration);
    final center = aroundFrameIndex.clamp(0, frameCount - 1);
    final order = <(CutId, int)>[(cutId, center)];
    for (var distance = 1; distance < frameCount; distance += 1) {
      if (center + distance < frameCount) {
        order.add((cutId, center + distance));
      }
      if (center - distance >= 0) {
        order.add((cutId, center - distance));
      }
    }
    _restart(order, quality);
  }

  /// Warms a multi-cut playlist sequentially (play-all).
  void requestWarmFrames({
    required List<(CutId, int)> frames,
    required PlaybackQuality quality,
  }) {
    _restart(List.of(frames), quality);
  }

  /// Restarts the idle debounce; warming stays paused while edits are hot.
  void notifyEditActivity() {
    _lastActivity = DateTime.now();
  }

  void cancel() {
    _generation += 1;
    _progress.value = PrerenderProgress.none;
  }

  void dispose() {
    _disposed = true;
    _generation += 1;
    _progress.dispose();
  }

  void _restart(List<(CutId, int)> queue, PlaybackQuality quality) {
    final generation = ++_generation;
    _progress.value = PrerenderProgress(cached: 0, total: queue.length);
    _current = _run(generation, queue, quality);
  }

  Future<void> _run(
    int generation,
    List<(CutId, int)> queue,
    PlaybackQuality quality,
  ) async {
    var cached = 0;
    for (final (cutId, frameIndex) in queue) {
      await _idleGate(generation);
      if (_isStale(generation)) {
        return;
      }
      final cut = resolveCut(cutId);
      if (cut != null) {
        final alreadyValid =
            composites.validCompositeOrNull(
              cut: cut,
              frameIndex: frameIndex,
              quality: quality,
            ) !=
            null;
        if (!alreadyValid) {
          await composites.prepareComposite(
            cut: cut,
            frameIndex: frameIndex,
            quality: quality,
          );
          if (_isStale(generation)) {
            return;
          }
          afterFrameCached?.call();
        }
      }
      cached += 1;
      _progress.value = PrerenderProgress(cached: cached, total: queue.length);
      // Yield so interactive work interleaves between frames.
      await Future<void>.delayed(Duration.zero);
      if (_isStale(generation)) {
        return;
      }
    }
  }

  bool _isStale(int generation) => _disposed || generation != _generation;

  Future<void> _idleGate(int generation) async {
    while (!_isStale(generation)) {
      final sinceActivity = DateTime.now().difference(_lastActivity);
      if (sinceActivity >= idleDelay) {
        return;
      }
      final remaining = idleDelay - sinceActivity;
      await Future<void>.delayed(
        remaining < const Duration(milliseconds: 50)
            ? remaining
            : const Duration(milliseconds: 50),
      );
    }
  }
}
