import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../ui/storyboard_timeline_layout.dart';

/// Wall-clock elapsed time → global frame index at [fps]. Elapsed-based
/// mapping is what makes playback drop frames instead of slowing down.
int elapsedToGlobalFrame(Duration elapsed, int fps) {
  return (elapsed.inMicroseconds * fps) ~/ Duration.microsecondsPerSecond;
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
