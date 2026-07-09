import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_cut_helpers.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/models/audio_clip.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/ui/export/export_plan.dart';
import 'package:quick_animaker_v2/src/ui/export/video_export_service.dart';

void main() {
  Frame frame(String id) =>
      Frame(id: FrameId(id), duration: 1, strokes: const []);

  Layer layer(
    String id, {
    String name = 'A',
    List<Frame> frames = const [],
    bool isVisible = true,
  }) =>
      Layer(id: LayerId(id), name: name, frames: frames, isVisible: isVisible);

  Cut cut(
    String id, {
    String name = 'Cut',
    int duration = 3,
    List<Layer>? layers,
  }) => Cut(
    id: CutId(id),
    name: name,
    duration: duration,
    canvasSize: const CanvasSize(width: 8, height: 8),
    layers: layers ?? [layer('$id-layer'), createCameraLayer(cutId: CutId(id))],
  );

  Project project(List<Track> tracks) => Project(
    id: const ProjectId('project'),
    name: 'Project',
    cameraSize: const CanvasSize(width: 32, height: 18),
    tracks: tracks,
    createdAt: DateTime.utc(2026),
  );

  group('buildExportFramePlan', () {
    test('active cut covers exactly its frames', () {
      final plan = buildExportFramePlan(
        project: project([
          Track(
            id: const TrackId('track'),
            name: 'Track',
            cuts: [cut('a', duration: 2), cut('b', duration: 3)],
          ),
        ]),
        activeCutId: const CutId('a'),
        range: ExportRange.activeCut,
      );

      expect(plan, hasLength(2));
      expect(plan.map((task) => task.cut.id.value), everyElement('a'));
      expect(plan.map((task) => task.frameIndex), [0, 1]);
    });

    test("all cuts walks the active cut's track in order, other tracks "
        'excluded', () {
      final plan = buildExportFramePlan(
        project: project([
          Track(
            id: const TrackId('track'),
            name: 'Track',
            cuts: [cut('a', duration: 2), cut('b', duration: 3)],
          ),
          Track(
            id: const TrackId('other'),
            name: 'Other',
            cuts: [cut('c', duration: 10)],
          ),
        ]),
        activeCutId: const CutId('b'),
        range: ExportRange.allCuts,
      );

      expect(plan, hasLength(5));
      expect(plan.map((task) => task.cut.id.value), ['a', 'a', 'b', 'b', 'b']);
      expect(plan.map((task) => task.frameIndex), [0, 1, 0, 1, 2]);
    });

    test('frame range is 0-based inclusive and clamps to the cut', () {
      final tracks = [
        Track(
          id: const TrackId('track'),
          name: 'Track',
          cuts: [cut('a', duration: 5)],
        ),
      ];

      final inner = buildExportFramePlan(
        project: project(tracks),
        activeCutId: const CutId('a'),
        range: ExportRange.frameRange,
        rangeStartFrame: 1,
        rangeEndFrame: 3,
      );
      expect(inner.map((task) => task.frameIndex), [1, 2, 3]);

      final clamped = buildExportFramePlan(
        project: project(tracks),
        activeCutId: const CutId('a'),
        range: ExportRange.frameRange,
        rangeStartFrame: -2,
        rangeEndFrame: 99,
      );
      expect(clamped.map((task) => task.frameIndex), [0, 1, 2, 3, 4]);
    });

    test('a zero-duration cut still exports one frame (playback floor)', () {
      final plan = buildExportFramePlan(
        project: project([
          Track(
            id: const TrackId('track'),
            name: 'Track',
            cuts: [cut('a', duration: 0)],
          ),
        ]),
        activeCutId: const CutId('a'),
        range: ExportRange.activeCut,
      );

      expect(plan.map((task) => task.frameIndex), [0]);
    });
  });

  group('buildExportCelPlan', () {
    test('lists each authored frame of visible drawing layers once, '
        'skipping camera and hidden layers', () {
      final plan = buildExportCelPlan(
        project: project([
          Track(
            id: const TrackId('track'),
            name: 'Track',
            cuts: [
              cut(
                'a',
                name: 'Cut',
                layers: [
                  layer('draw', name: 'A', frames: [frame('f1'), frame('f2')]),
                  layer(
                    'hidden',
                    name: 'H',
                    frames: [frame('f3')],
                    isVisible: false,
                  ),
                  createCameraLayer(cutId: const CutId('a')),
                ],
              ),
            ],
          ),
        ]),
        activeCutId: const CutId('a'),
        range: ExportRange.activeCut,
      );

      expect(plan, hasLength(2));
      expect(plan.map((task) => task.frame.id.value), ['f1', 'f2']);
      // Default naming: layer name + frame name (position fallback when the
      // frame is unnamed).
      expect(plan.map((task) => task.fileName), ['A1.png', 'A2.png']);
    });

    test('onTimesheetOnly keeps only layers marked for the sheet', () {
      final tracks = [
        Track(
          id: const TrackId('track'),
          name: 'Track',
          cuts: [
            cut(
              'a',
              layers: [
                layer('on-sheet', name: 'A', frames: [frame('f1')]),
                layer(
                  'off-sheet',
                  name: 'B',
                  frames: [frame('f2')],
                ).copyWith(onTimesheet: false),
              ],
            ),
          ],
        ),
      ];

      final all = buildExportCelPlan(
        project: project(tracks),
        activeCutId: const CutId('a'),
        range: ExportRange.activeCut,
      );
      expect(all.map((task) => task.layer.name), ['A', 'B']);

      final sheetOnly = buildExportCelPlan(
        project: project(tracks),
        activeCutId: const CutId('a'),
        range: ExportRange.activeCut,
        onTimesheetOnly: true,
      );
      expect(sheetOnly.map((task) => task.layer.name), ['A']);
    });

    test('frame range covers the whole active cut for cels', () {
      final plan = buildExportCelPlan(
        project: project([
          Track(
            id: const TrackId('track'),
            name: 'Track',
            cuts: [
              cut(
                'a',
                layers: [
                  layer('draw', frames: [frame('f1'), frame('f2')]),
                  createCameraLayer(cutId: const CutId('a')),
                ],
              ),
            ],
          ),
        ]),
        activeCutId: const CutId('a'),
        range: ExportRange.frameRange,
      );

      expect(plan, hasLength(2));
    });

    test('duplicate cut/layer names bump the file name instead of '
        'colliding', () {
      final plan = buildExportCelPlan(
        project: project([
          Track(
            id: const TrackId('track'),
            name: 'Track',
            cuts: [
              cut(
                'a',
                name: 'Cut',
                layers: [
                  layer('one', name: 'A', frames: [frame('f1')]),
                  layer('two', name: 'A', frames: [frame('f2')]),
                ],
              ),
            ],
          ),
        ]),
        activeCutId: const CutId('a'),
        range: ExportRange.activeCut,
      );

      expect(plan.map((task) => task.fileName), ['A1.png', 'A1_2.png']);
    });

    test('naming options assemble project/cut prefixes, digits, suffix and '
        'folders', () {
      final tracks = [
        Track(
          id: const TrackId('track'),
          name: 'Track',
          cuts: [
            cut(
              'a',
              name: 'C01',
              layers: [
                layer(
                  'draw',
                  name: 'A',
                  frames: [
                    Frame(
                      id: const FrameId('f1'),
                      duration: 1,
                      strokes: const [],
                      name: '3',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];

      List<String> namesFor(ExportCelNaming naming) => buildExportCelPlan(
        project: project(tracks),
        activeCutId: const CutId('a'),
        range: ExportRange.activeCut,
        naming: naming,
      ).map((task) => task.fileName).toList();

      expect(
        namesFor(
          const ExportCelNaming(
            includeProjectName: true,
            includeCutName: true,
            frameDigits: 4,
          ),
        ),
        ['Project_C01_A0003.png'],
      );
      expect(namesFor(const ExportCelNaming(includeLayerName: false)), [
        '3.png',
      ]);
      expect(namesFor(const ExportCelNaming(suffix: '_fix')), ['A3_fix.png']);
      expect(
        namesFor(const ExportCelNaming(cutFolder: true, layerFolder: true)),
        ['C01/A/A3.png'],
      );
    });
  });

  group('padFrameNumber', () {
    test('pads the first digit run and leaves the rest alone', () {
      expect(padFrameNumber('1', 4), '0001');
      expect(padFrameNumber('12', 3), '012');
      expect(padFrameNumber('a12b', 4), 'a0012b');
      expect(padFrameNumber('1234', 4), '1234');
      expect(padFrameNumber('12345', 4), '12345');
      expect(padFrameNumber('abc', 4), 'abc');
      expect(padFrameNumber('1', 0), '1');
    });
  });

  group('sanitizeExportFileComponent', () {
    test('replaces characters Windows forbids and trims trailing dots', () {
      expect(sanitizeExportFileComponent('Cut: 1?'), 'Cut_ 1_');
      expect(sanitizeExportFileComponent(r'a\b/c'), 'a_b_c');
      expect(sanitizeExportFileComponent('name...'), 'name');
      expect(sanitizeExportFileComponent('   '), 'untitled');
      expect(sanitizeExportFileComponent(''), 'untitled');
    });
  });

  group('buildExportAudioPlan', () {
    // Frame-linked sounds: one SE layer per sound, its block = the window.
    Layer seLayer(
      String id, {
      required String file,
      required int start,
      required int length,
    }) => Layer(
      id: LayerId(id),
      name: 'S1',
      kind: LayerKind.se,
      frames: [
        Frame(id: FrameId('$id-frame'), duration: 1, strokes: const []),
      ],
      timeline: {
        start: TimelineExposure.drawing(FrameId('$id-frame'), length: length),
      },
      audioClips: [AudioClip(filePath: file, frameId: FrameId('$id-frame'))],
    );

    // fps 10 for readable seconds. Cut a: 10 frames, blocks at 0 (full cut)
    // and 6..10. Cut b: 20 frames, block at local 3 (global 13 in all-cuts
    // order) running to the cut end.
    Cut cutA() => cut(
      'a',
      duration: 10,
      layers: [
        seLayer('se-a1', file: 'a.wav', start: 0, length: 10),
        seLayer('se-a2', file: 'b.wav', start: 6, length: 4),
      ],
    );
    Cut cutB() => cut(
      'b',
      duration: 20,
      layers: [seLayer('se-b', file: 'c.wav', start: 3, length: 17)],
    );

    test('all-cuts export lays clips globally, capped at their cut blocks', () {
      final plan = buildExportFramePlan(
        project: project([
          Track(
            id: const TrackId('track'),
            name: 'Track',
            cuts: [cutA(), cutB()],
          ),
        ]),
        activeCutId: const CutId('a'),
        range: ExportRange.allCuts,
      );

      final clips = buildExportAudioPlan(plan: plan, fps: 10);

      expect(clips, const [
        // a.wav fills its whole cut.
        ExportAudioClip(filePath: 'a.wav', durationSeconds: 1.0),
        // b.wav starts at frame 6 and caps at cut a's end (frame 10).
        ExportAudioClip(
          filePath: 'b.wav',
          delaySeconds: 0.6,
          durationSeconds: 0.4,
        ),
        // c.wav sits at global frame 13 (cut b local 3) and never bleeds
        // past cut b.
        ExportAudioClip(
          filePath: 'c.wav',
          delaySeconds: 1.3,
          durationSeconds: 1.7,
        ),
      ]);
    });

    test('a frame-range export seeks into clips that started earlier and '
        'drops clips past the range', () {
      final plan = buildExportFramePlan(
        project: project([
          Track(id: const TrackId('track'), name: 'Track', cuts: [cutA()]),
        ]),
        activeCutId: const CutId('a'),
        range: ExportRange.frameRange,
        rangeStartFrame: 4,
        rangeEndFrame: 5,
      );

      final clips = buildExportAudioPlan(plan: plan, fps: 10);

      expect(clips, const [
        // a.wav began 4 frames before the range: seek 0.4s in, play from
        // the video's start, for the 2-frame range.
        ExportAudioClip(
          filePath: 'a.wav',
          seekSeconds: 0.4,
          durationSeconds: 0.2,
        ),
        // b.wav (frame 6) starts after the exported range ends → silent.
      ]);
    });
  });
}
