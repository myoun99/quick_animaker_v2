import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/playback/playback_frame_mapping.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_timeline_layout.dart';

void main() {
  Cut cut(String id, int duration) => Cut(
    id: CutId(id),
    name: id,
    layers: const [],
    duration: duration,
    canvasSize: const CanvasSize(width: 8, height: 8),
  );

  List<StoryboardTimelineLayoutEntry> playlist() {
    return buildStoryboardTimelineLayout(
      Project(
        id: const ProjectId('project'),
        name: 'Project',
        tracks: [
          Track(
            id: const TrackId('track'),
            name: 'Track',
            cuts: [cut('cut-a', 4), cut('cut-b', 6)],
          ),
        ],
        createdAt: DateTime.utc(2026),
      ),
    );
  }

  test('elapsedToGlobalFrame maps wall clock to frames at fps', () {
    expect(elapsedToGlobalFrame(Duration.zero, 24), 0);
    expect(elapsedToGlobalFrame(const Duration(milliseconds: 41), 24), 0);
    expect(elapsedToGlobalFrame(const Duration(milliseconds: 42), 24), 1);
    expect(elapsedToGlobalFrame(const Duration(seconds: 1), 24), 24);
    expect(elapsedToGlobalFrame(const Duration(seconds: 2), 12), 24);
  });

  test('resolvePlaybackPosition finds the cut and local frame', () {
    final entries = playlist();

    final inFirst = resolvePlaybackPosition(
      playlist: entries,
      globalFrameIndex: 3,
    )!;
    expect(inFirst.cutId, const CutId('cut-a'));
    expect(inFirst.localFrameIndex, 3);

    final inSecond = resolvePlaybackPosition(
      playlist: entries,
      globalFrameIndex: 4,
    )!;
    expect(inSecond.cutId, const CutId('cut-b'));
    expect(inSecond.localFrameIndex, 0);

    expect(
      resolvePlaybackPosition(playlist: entries, globalFrameIndex: 10),
      isNull,
    );
    expect(
      resolvePlaybackPosition(playlist: entries, globalFrameIndex: -1),
      isNull,
    );
  });

  test('playlistTotalFrames sums sequential cut durations', () {
    expect(playlistTotalFrames(playlist()), 10);
    expect(playlistTotalFrames(const []), 0);
  });

  test('gap frames resolve to null (black) but still count toward the '
      'total', () {
    final entries = buildStoryboardTimelineLayout(
      Project(
        id: const ProjectId('gap-project'),
        name: 'Gaps',
        tracks: [
          Track(
            id: const TrackId('track'),
            name: 'Track',
            cuts: [
              cut('cut-a', 4),
              Cut(
                id: const CutId('cut-b'),
                name: 'cut-b',
                layers: const [],
                duration: 6,
                leadingGapFrames: 3,
                canvasSize: const CanvasSize(width: 8, height: 8),
              ),
            ],
          ),
        ],
        createdAt: DateTime.utc(2026),
      ),
    );

    // Frames 4..6 sit in the gap: no cut plays there.
    expect(
      resolvePlaybackPosition(playlist: entries, globalFrameIndex: 3),
      isNotNull,
    );
    for (var frame = 4; frame < 7; frame += 1) {
      expect(
        resolvePlaybackPosition(playlist: entries, globalFrameIndex: frame),
        isNull,
        reason: 'frame $frame is in the gap',
      );
    }
    final afterGap = resolvePlaybackPosition(
      playlist: entries,
      globalFrameIndex: 7,
    )!;
    expect(afterGap.cutId, const CutId('cut-b'));
    expect(afterGap.localFrameIndex, 0);

    // The playback clock runs THROUGH the gap: total = last end.
    expect(playlistTotalFrames(entries), 13);
  });
}
