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
import 'package:quick_animaker_v2/src/ui/export/export_plan.dart';

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
      expect(plan.map((task) => task.fileName), [
        'Cut_A_0001.png',
        'Cut_A_0002.png',
      ]);
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

      expect(plan.map((task) => task.fileName), [
        'Cut_A_0001.png',
        'Cut_A_0001_2.png',
      ]);
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
}
