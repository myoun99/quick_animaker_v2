import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_cut_helpers.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';

void main() {
  group('createDefaultCut', () {
    test('creates a default empty cut with caller-provided ids and name', () {
      final cut = createDefaultCut(
        cutId: const CutId('cut-new'),
        name: 'Opening Cut',
        layerId: const LayerId('layer-new'),
      );

      expect(cut.id, const CutId('cut-new'));
      expect(cut.name, 'Opening Cut');
      expect(cut.duration, defaultCutDuration);
      expect(cut.canvasSize, const CanvasSize(width: 1280, height: 720));
      expect(cut.layers, hasLength(1));

      final layer = cut.layers.single;
      expect(layer.id, const LayerId('layer-new'));
      expect(layer.name, 'A');
      expect(layer.kind, LayerKind.animation);
      expect(layer.frames, isEmpty);
      expect(layer.timeline[0], const TimelineExposure.blank());
      expect(layer.marks, isEmpty);
      expect(layer.isVisible, isTrue);
      expect(layer.opacity, 1.0);
    });

    test('uses the Phase 104 default duration for newly created cuts', () {
      final cut = createDefaultCut(
        cutId: const CutId('cut-new'),
        name: 'New Cut',
        layerId: const LayerId('layer-new'),
      );

      expect(defaultCutDuration, 24);
      expect(cut.duration, 24);
    });

    test('uses a caller-provided canvas size', () {
      final cut = createDefaultCut(
        cutId: const CutId('cut-custom-size'),
        name: 'Custom Size Cut',
        layerId: const LayerId('layer-custom-size'),
        canvasSize: const CanvasSize(width: 1920, height: 1080),
      );

      expect(cut.canvasSize, const CanvasSize(width: 1920, height: 1080));
    });

    test('does not enforce unique cut names', () {
      final first = createDefaultCut(
        cutId: const CutId('cut-1'),
        name: 'Duplicate Name',
        layerId: const LayerId('layer-1'),
      );
      final second = createDefaultCut(
        cutId: const CutId('cut-2'),
        name: 'Duplicate Name',
        layerId: const LayerId('layer-2'),
      );

      expect(first.name, second.name);
      expect(first.id, isNot(second.id));
      expect(first.layers.single.id, isNot(second.layers.single.id));
    });

    test('does not mutate a project', () {
      final project = Project(
        id: const ProjectId('project'),
        name: 'Project',
        tracks: [
          Track(
            id: const TrackId('track'),
            name: 'Track',
            cuts: const [],
            type: TrackType.video,
          ),
        ],
        createdAt: DateTime.utc(2026),
      );

      createDefaultCut(
        cutId: const CutId('cut-new'),
        name: 'New Cut',
        layerId: const LayerId('layer-new'),
      );

      expect(project.tracks.single.cuts, isEmpty);
    });
  });
}
