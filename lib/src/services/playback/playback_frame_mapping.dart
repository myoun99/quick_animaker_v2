import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/project_frame_rate.dart';
import '../../ui/storyboard_timeline_layout.dart';

/// Wall-clock elapsed time → global frame index at [rate]. Elapsed-based
/// mapping is what makes playback drop frames instead of slowing down.
///
/// RT: the rate is the exact fraction, so a 23.976 project maps time to
/// frames without the 0.1% error a rounded 24 would accumulate — after an
/// hour that error is 3.6 seconds of drift.
int elapsedToGlobalFrame(Duration elapsed, ProjectFrameRate rate) {
  return rate.frameAtElapsed(elapsed);
}

/// Where a global playlist frame lands: which cut, and which local frame.
class PlaybackPosition {
  const PlaybackPosition({
    required this.cut,
    required this.localFrameIndex,
    required this.globalFrameIndex,
  });

  /// The cut snapshot from the playlist (frozen at play start).
  final Cut cut;
  final int localFrameIndex;
  final int globalFrameIndex;

  CutId get cutId => cut.id;

  @override
  String toString() =>
      'PlaybackPosition(cut: ${cut.id}, local: $localFrameIndex, '
      'global: $globalFrameIndex)';
}

/// Resolves [globalFrameIndex] against sequential playlist entries
/// (endFrame exclusive); `null` when out of range or on zero-length cuts.
PlaybackPosition? resolvePlaybackPosition({
  required List<StoryboardTimelineLayoutEntry> playlist,
  required int globalFrameIndex,
}) {
  for (final entry in playlist) {
    if (globalFrameIndex >= entry.startFrame &&
        globalFrameIndex < entry.endFrame) {
      return PlaybackPosition(
        cut: entry.cut,
        localFrameIndex: globalFrameIndex - entry.startFrame,
        globalFrameIndex: globalFrameIndex,
      );
    }
  }
  return null;
}

int playlistTotalFrames(List<StoryboardTimelineLayoutEntry> playlist) {
  return playlist.isEmpty ? 0 : playlist.last.endFrame;
}
