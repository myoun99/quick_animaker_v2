import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/audio_clip.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/cut_metadata.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_exposure_comma_drag_policy.dart'
    show TimelineCommaDragCallbacks;
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
  void Function(CutId cutId, CutFadeTarget fadeTarget)? onSetCutFadeTarget,
  ValueChanged<LayerId>? onToggleLayerVisibility,
  ValueChanged<LayerId>? onToggleLayerMuted,
  void Function(LayerId layerId, double opacity)? onLayerOpacityChanged,
  void Function(CutId cutId, LayerId layerId, int blockStartFrame)?
  onSelectSeBlock,
  TimelineCommaDragCallbacks? seCommaDrag,
  void Function(LayerId layerId, int clipIndex, int offsetFrames)?
  onSetAudioClipOffset,
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
            onSetCutFadeTarget: onSetCutFadeTarget,
            onToggleLayerVisibility: onToggleLayerVisibility,
            onToggleLayerMuted: onToggleLayerMuted,
            onLayerOpacityChanged: onLayerOpacityChanged,
            onSelectSeBlock: onSelectSeBlock,
            seCommaDrag: seCommaDrag,
            onSetAudioClipOffset: onSetAudioClipOffset,
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
    // The lane carries the clip's enlarged waveform span — the REUSED
    // timeline Audio lane substrate ('완벽통일': its span keys ride the
    // storyboard-<cutId> prefix).
    expect(
      find.byKey(
        const ValueKey<String>(
          'storyboard-lane-cut-audio-lane-span-lane-se-0-b0',
        ),
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

  testWidgets('the fade span\'s context menu sets the fade TARGET '
      '(FO=black default, WO=white)', (tester) async {
    final targets = <(CutId, CutFadeTarget)>[];
    await _pumpPanel(
      tester,
      project: _project(),
      onSetCutFade: (_, _, _) {},
      onSetCutFadeTarget: (cutId, target) => targets.add((cutId, target)),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('storyboard-track-lane-toggle-lane-track'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey<String>('storyboard-cut-fade-span-lane-cut')),
    );
    await tester.pumpAndSettle();

    // Black is checked by default; picking White commits.
    await tester.tap(
      find.byKey(const ValueKey<String>('cut-fade-target-white')),
    );
    await tester.pumpAndSettle();

    expect(targets, [(const CutId('lane-cut'), CutFadeTarget.white)]);
  });

  group('timeline-parity S rows (R4-⑨ 완벽통일)', () {
    testWidgets('the rail carries the ACTIVE cut layer\'s eye/mute/opacity '
        'controls with the shared session hooks', (tester) async {
      final visibilityToggles = <LayerId>[];
      final muteToggles = <LayerId>[];
      final opacityChanges = <(LayerId, double)>[];
      await _pumpPanel(
        tester,
        project: _project(),
        onToggleLayerVisibility: visibilityToggles.add,
        onToggleLayerMuted: muteToggles.add,
        onLayerOpacityChanged: (layerId, opacity) =>
            opacityChanges.add((layerId, opacity)),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('storyboard-layer-visibility-lane-se'),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('storyboard-layer-mute-lane-se')),
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('storyboard-layer-opacity-lane-se')),
        const Offset(-20, 0),
      );
      await tester.pumpAndSettle();

      expect(visibilityToggles, [const LayerId('lane-se')]);
      expect(muteToggles, [const LayerId('lane-se')]);
      expect(opacityChanges, isNotEmpty);
      expect(opacityChanges.last.$1, const LayerId('lane-se'));
      expect(opacityChanges.last.$2, lessThan(1));
    });

    testWidgets('tapping an SE block selects its cut/layer/frame '
        '(timeline cell-tap parity)', (tester) async {
      final selections = <(CutId, LayerId, int)>[];
      await _pumpPanel(
        tester,
        project: _project(),
        onSelectSeBlock: (cutId, layerId, start) =>
            selections.add((cutId, layerId, start)),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('storyboard-se-block-select-lane-cut-0'),
        ),
      );
      await tester.pumpAndSettle();

      expect(selections, [
        (const CutId('lane-cut'), const LayerId('lane-se'), 0),
      ]);
    });

    testWidgets('the ACTIVE cut\'s SE blocks carry the timeline comma '
        'grips: an end-edge drag rides the session drag hooks', (tester) async {
      final log = <String>[];
      await _pumpPanel(
        tester,
        project: _project(),
        seCommaDrag: TimelineCommaDragCallbacks(
          onBegin: (layerId, blockStartIndex, edge) {
            log.add('begin $layerId $blockStartIndex ${edge.name}');
            return true;
          },
          onUpdate: (delta) => log.add('update $delta'),
          onEnd: () => log.add('end'),
          onCancel: () => log.add('cancel'),
        ),
      );

      // 12px per frame; the recognizer's slop eats ~20px, so 48px lands a
      // whole-frame delta (same allowance as the XSheet grip tests).
      await tester.drag(
        find.byKey(const ValueKey<String>('storyboard-se-grip-lane-cut-0-end')),
        const Offset(48, 0),
      );
      await tester.pumpAndSettle();

      expect(log.first, 'begin lane-se 0 end');
      expect(
        log.where((entry) => entry.startsWith('update')),
        isNotEmpty,
        reason: 'the drag must report whole-frame deltas',
      );
      expect(log.last, 'end');
    });

    testWidgets('the twirled-down audio lane IS the timeline lane substrate '
        'and slide-edits the ACTIVE cut\'s clip', (tester) async {
      final offsets = <(LayerId, int, int)>[];
      await _pumpPanel(
        tester,
        project: _project(),
        onSetAudioClipOffset: (layerId, clipIndex, offsetFrames) =>
            offsets.add((layerId, clipIndex, offsetFrames)),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('storyboard-se-lane-toggle-lane-track-1'),
        ),
      );
      await tester.pumpAndSettle();

      final span = find.byKey(
        const ValueKey<String>(
          'storyboard-lane-cut-audio-lane-span-lane-se-0-b0',
        ),
      );
      expect(span, findsOneWidget, reason: 'the reused timeline lane span');

      // Slide LEFT (a later part of the file plays at the block start —
      // offset grows; rightward from offset 0 clamps to no-op), exactly
      // like the timeline's Audio lane.
      await tester.drag(span, const Offset(-60, 0));
      await tester.pumpAndSettle();

      expect(offsets, isNotEmpty);
      expect(offsets.last.$1, const LayerId('lane-se'));
      expect(offsets.last.$3, greaterThan(0));
    });
  });
}
