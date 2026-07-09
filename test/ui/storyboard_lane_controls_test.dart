import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/audio_clip.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/audio/audio_peaks_extractor.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_cut_fade_policy.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_panel.dart';

/// One second at half amplitude → 24 frames at 24 fps.
final _peaks = AudioPeaks(
  bucketsPerSecond: 80,
  peaks: Float32List.fromList(List.filled(80, 0.5)),
);

Layer _seLayer() => Layer(
  id: const LayerId('lane-se'),
  name: 'S1',
  kind: LayerKind.se,
  frames: [Frame(id: const FrameId('lane-f'), duration: 8, strokes: const [])],
  timeline: {0: const TimelineExposure.drawing(FrameId('lane-f'), length: 8)},
  audioClips: const [
    AudioClip(filePath: 'voice.wav', frameId: FrameId('lane-f')),
  ],
);

Project _project({Cut Function(Cut cut)? mapCut}) {
  var cut = Cut(
    id: const CutId('lane-cut'),
    name: 'Lane Cut',
    duration: 10,
    canvasSize: const CanvasSize(width: 640, height: 360),
    layers: [_seLayer()],
  );
  if (mapCut != null) {
    cut = mapCut(cut);
  }
  return Project(
    id: const ProjectId('lane-project'),
    name: 'Lanes',
    createdAt: DateTime.utc(2026, 7, 10),
    tracks: [
      Track(id: const TrackId('lane-track'), name: 'Video', cuts: [cut]),
    ],
  );
}

/// Pumps the panel with host-style toggle wiring (view-state sets live in
/// the harness, like StoryboardTabHost).
Future<void> _pumpPanel(
  WidgetTester tester, {
  required Project project,
  void Function(CutId cutId, int fadeInFrames, int fadeOutFrames)? onSetCutFade,
}) async {
  final hiddenWaveforms = <String>{};
  final expandedAudio = <String>{};
  final expandedOpacity = <String>{};
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => StoryboardPanel(
            project: project,
            activeCutId: const CutId('lane-cut'),
            onCutSelected: (_) {},
            pixelsPerFrame: 12,
            projectFps: 24,
            audioPeaksFor: (path) => path == 'voice.wav' ? _peaks : null,
            hiddenWaveformSeRows: hiddenWaveforms,
            onToggleSeRowWaveform: (track, slot) => setState(() {
              final key = StoryboardPanel.seRowKey(track, slot);
              if (!hiddenWaveforms.add(key)) {
                hiddenWaveforms.remove(key);
              }
            }),
            expandedSeAudioRows: expandedAudio,
            onToggleSeRowLane: (track, slot) => setState(() {
              final key = StoryboardPanel.seRowKey(track, slot);
              if (!expandedAudio.add(key)) {
                expandedAudio.remove(key);
              }
            }),
            expandedOpacityTracks: expandedOpacity,
            onToggleTrackLane: (track) => setState(() {
              if (!expandedOpacity.add(track.id.value)) {
                expandedOpacity.remove(track.id.value);
              }
            }),
            onSetCutFade: onSetCutFade,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the V-track chevron twirls down the Opacity lane and the '
      'S-row chevron the audio lane, timeline-style', (tester) async {
    await _pumpPanel(tester, project: _project());

    // Collapsed: no lane rows.
    expect(
      find.byKey(const ValueKey<String>('storyboard-opacity-lane-row-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('storyboard-audio-lane-row-0-1')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('storyboard-track-lane-toggle-lane-track'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('storyboard-opacity-lane-row-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('storyboard-lane-label-lane-track-opacity'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('storyboard-se-lane-toggle-lane-track-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('storyboard-audio-lane-row-0-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('storyboard-lane-label-lane-track-s1-audio'),
      ),
      findsOneWidget,
    );
    // The lane carries the clip's enlarged waveform span.
    expect(
      find.byKey(
        const ValueKey<String>('storyboard-audio-lane-span-lane-cut-0-b0'),
      ),
      findsOneWidget,
    );

    // Chevrons twirl back up.
    await tester.tap(
      find.byKey(
        const ValueKey<String>('storyboard-track-lane-toggle-lane-track'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('storyboard-opacity-lane-row-0')),
      findsNothing,
    );
  });

  testWidgets('the S-row eye toggles the waveform display', (tester) async {
    await _pumpPanel(tester, project: _project());

    expect(
      find.byKey(const ValueKey<String>('storyboard-audio-clip-lane-cut-0-b0')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('storyboard-se-waveform-toggle-lane-track-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('storyboard-audio-clip-lane-cut-0-b0')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('storyboard-se-waveform-toggle-lane-track-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('storyboard-audio-clip-lane-cut-0-b0')),
      findsOneWidget,
    );
  });

  testWidgets('dragging the cut-fade handles commits the fade lengths '
      '(one commit per drag)', (tester) async {
    final commits = <(CutId, int, int)>[];
    await _pumpPanel(
      tester,
      project: _project(),
      onSetCutFade: (cutId, fadeIn, fadeOut) =>
          commits.add((cutId, fadeIn, fadeOut)),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('storyboard-track-lane-toggle-lane-track'),
      ),
    );
    await tester.pumpAndSettle();

    // 12 px/frame: 3 frames = 36 px rightward on the fade-in handle.
    await tester.drag(
      find.byKey(
        const ValueKey<String>('storyboard-cut-fade-in-handle-lane-cut'),
      ),
      const Offset(36, 0),
    );
    await tester.pumpAndSettle();
    expect(commits, [(const CutId('lane-cut'), 3, 0)]);

    // 2 frames leftward on the fade-out handle.
    await tester.drag(
      find.byKey(
        const ValueKey<String>('storyboard-cut-fade-out-handle-lane-cut'),
      ),
      const Offset(-24, 0),
    );
    await tester.pumpAndSettle();
    expect(commits, [
      (const CutId('lane-cut'), 3, 0),
      (const CutId('lane-cut'), 0, 2),
    ]);
  });

  testWidgets('existing fade keys read back into the handles: dragging '
      'extends from the current lengths', (tester) async {
    final commits = <(CutId, int, int)>[];
    await _pumpPanel(
      tester,
      project: _project(
        mapCut: (cut) => cut.copyWith(
          transformTrack: cutTransformWithFade(
            cut,
            fadeInFrames: 2,
            fadeOutFrames: 0,
          ),
        ),
      ),
      onSetCutFade: (cutId, fadeIn, fadeOut) =>
          commits.add((cutId, fadeIn, fadeOut)),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('storyboard-track-lane-toggle-lane-track'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(
        const ValueKey<String>('storyboard-cut-fade-in-handle-lane-cut'),
      ),
      const Offset(24, 0),
    );
    await tester.pumpAndSettle();
    expect(commits, [(const CutId('lane-cut'), 4, 0)]);
  });
}
