import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_settings.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/cut_metadata.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/storyboard_frame_metadata.dart';
import 'package:quick_animaker_v2/src/models/stroke.dart';
import 'package:quick_animaker_v2/src/models/stroke_id.dart';
import 'package:quick_animaker_v2/src/models/stroke_point.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/timeline_mark.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/commands/update_layer_kind_command.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';

void main() {
  group('UpdateLayerKindCommand', () {
    test(
      'execute changes animation layer to storyboard and preserves data',
      () {
        const metadata = StoryboardFrameMetadata(
          actionMemo: 'Action',
          dialogueMemo: 'Dialogue',
          note: 'Panel note',
        );
        final stroke = _stroke('stroke-1');
        final frame = _frame(
          id: 'frame-1',
          strokes: [stroke],
          metadata: metadata,
        );
        final layer = _layer(
          id: 'layer-1',
          frames: [frame],
          timeline: {
            0: TimelineExposure.drawing(frame.id),
            4: const TimelineExposure.blank(),
          },
          marks: const {4: TimelineMark.inbetween()},
          isVisible: false,
          opacity: 0.42,
        );
        final cut = _cut(
          id: 'cut-1',
          layers: [layer],
          metadata: const CutMetadata(note: 'Cut note'),
        );
        final repository = ProjectRepository(initialProject: _project([cut]));

        UpdateLayerKindCommand(
          repository: repository,
          cutId: cut.id,
          layerId: layer.id,
          kind: LayerKind.storyboard,
        ).execute();

        final updatedCut = _cutById(repository.requireProject(), cut.id);
        final updatedLayer = updatedCut.layers.single;
        final updatedFrame = updatedLayer.frames.single;
        expect(updatedLayer.kind, LayerKind.storyboard);
        expect(updatedLayer.id, layer.id);
        expect(updatedLayer.name, layer.name);
        expect(updatedLayer.frames, [frame]);
        expect(updatedLayer.timeline, layer.timeline);
        expect(updatedLayer.marks, layer.marks);
        expect(updatedLayer.isVisible, isFalse);
        expect(updatedLayer.opacity, 0.42);
        expect(updatedFrame.storyboardMetadata, metadata);
        expect(updatedFrame.strokes, [stroke]);
        expect(updatedCut.metadata, const CutMetadata(note: 'Cut note'));
      },
    );

    test(
      'execute changes storyboard layer back to animation without metadata loss',
      () {
        const metadata = StoryboardFrameMetadata(actionMemo: 'Keep me');
        final frame = _frame(id: 'frame-1', metadata: metadata);
        final layer = _layer(
          id: 'layer-1',
          kind: LayerKind.storyboard,
          frames: [frame],
        );
        final cut = _cut(id: 'cut-1', layers: [layer]);
        final repository = ProjectRepository(initialProject: _project([cut]));

        UpdateLayerKindCommand(
          repository: repository,
          cutId: cut.id,
          layerId: layer.id,
          kind: LayerKind.animation,
        ).execute();

        final updatedLayer = _layerById(repository.requireProject(), layer.id);
        expect(updatedLayer.kind, LayerKind.animation);
        expect(updatedLayer.frames.single.storyboardMetadata, metadata);
      },
    );

    test('undo restores previous kind and redo reapplies new kind', () {
      final layer = _layer(id: 'layer-1');
      final cut = _cut(id: 'cut-1', layers: [layer]);
      final repository = ProjectRepository(initialProject: _project([cut]));
      final historyManager = HistoryManager();

      historyManager.execute(
        UpdateLayerKindCommand(
          repository: repository,
          cutId: cut.id,
          layerId: layer.id,
          kind: LayerKind.storyboard,
        ),
      );
      expect(
        _layerById(repository.requireProject(), layer.id).kind,
        LayerKind.storyboard,
      );

      historyManager.undo();
      expect(
        _layerById(repository.requireProject(), layer.id).kind,
        LayerKind.animation,
      );

      historyManager.redo();
      expect(
        _layerById(repository.requireProject(), layer.id).kind,
        LayerKind.storyboard,
      );
    });

    test('rejects animation to storyboard when another storyboard exists', () {
      final storyboardLayer = _layer(
        id: 'layer-storyboard',
        kind: LayerKind.storyboard,
      );
      final animationLayer = _layer(
        id: 'layer-animation',
        frames: [_frame(id: 'frame-animation', strokes: [_stroke('stroke')])],
        timeline: const {0: TimelineExposure.blank()},
        marks: const {0: TimelineMark.inbetween()},
      );
      final cut = _cut(id: 'cut-1', layers: [storyboardLayer, animationLayer]);
      final repository = ProjectRepository(initialProject: _project([cut]));
      final beforeJson = repository.requireProject().toJson();

      expect(
        () => UpdateLayerKindCommand(
          repository: repository,
          cutId: cut.id,
          layerId: animationLayer.id,
          kind: LayerKind.storyboard,
        ).execute(),
        throwsStateError,
      );
      expect(repository.requireProject().toJson(), beforeJson);
    });

    test('missing cut throws StateError', () {
      final layer = _layer(id: 'layer-1');
      final cut = _cut(id: 'cut-1', layers: [layer]);
      final repository = ProjectRepository(initialProject: _project([cut]));

      expect(
        () => UpdateLayerKindCommand(
          repository: repository,
          cutId: const CutId('missing'),
          layerId: layer.id,
          kind: LayerKind.storyboard,
        ).execute(),
        throwsStateError,
      );
    });

    test('missing layer throws StateError', () {
      final cut = _cut(
        id: 'cut-1',
        layers: [_layer(id: 'layer-1')],
      );
      final repository = ProjectRepository(initialProject: _project([cut]));

      expect(
        () => UpdateLayerKindCommand(
          repository: repository,
          cutId: cut.id,
          layerId: const LayerId('missing'),
          kind: LayerKind.storyboard,
        ).execute(),
        throwsStateError,
      );
    });

    test('unrelated cuts, layers, frames, and strokes are preserved', () {
      final targetFrame = _frame(id: 'frame-target', strokes: [_stroke('s1')]);
      final otherFrame = _frame(id: 'frame-other', strokes: [_stroke('s2')]);
      final targetLayer = _layer(id: 'layer-target', frames: [targetFrame]);
      final siblingLayer = _layer(id: 'layer-sibling', frames: [otherFrame]);
      final targetCut = _cut(
        id: 'cut-target',
        layers: [targetLayer, siblingLayer],
      );
      final otherCut = _cut(
        id: 'cut-other',
        layers: [_layer(id: 'layer-other')],
      );
      final repository = ProjectRepository(
        initialProject: _project([targetCut, otherCut]),
      );

      UpdateLayerKindCommand(
        repository: repository,
        cutId: targetCut.id,
        layerId: targetLayer.id,
        kind: LayerKind.storyboard,
      ).execute();

      final updatedTargetCut = _cutById(
        repository.requireProject(),
        targetCut.id,
      );
      expect(updatedTargetCut.layers[1], siblingLayer);
      expect(updatedTargetCut.layers.first.frames.single, targetFrame);
      expect(_cutById(repository.requireProject(), otherCut.id), otherCut);
    });
  });
}

Project _project(List<Cut> cuts) => Project(
  id: const ProjectId('project-1'),
  name: 'Project',
  tracks: [_track(cuts: cuts)],
  createdAt: DateTime.utc(2026, 6, 11),
);

Track _track({List<Cut> cuts = const []}) =>
    Track(id: const TrackId('track-1'), name: 'Video', cuts: cuts);

Cut _cut({
  required String id,
  List<Layer> layers = const [],
  CutMetadata metadata = const CutMetadata.empty(),
}) => Cut(
  id: CutId(id),
  name: id,
  layers: layers,
  duration: 24,
  canvasSize: const CanvasSize(width: 1920, height: 1080),
  metadata: metadata,
);

Layer _layer({
  required String id,
  List<Frame> frames = const [],
  Map<int, TimelineExposure>? timeline,
  Map<int, TimelineMark>? marks,
  LayerKind kind = LayerKind.animation,
  bool isVisible = true,
  double opacity = 1.0,
}) => Layer(
  id: LayerId(id),
  name: 'name-$id',
  frames: frames,
  timeline: timeline,
  marks: marks,
  kind: kind,
  isVisible: isVisible,
  opacity: opacity,
);

Frame _frame({
  required String id,
  List<Stroke> strokes = const [],
  StoryboardFrameMetadata metadata = const StoryboardFrameMetadata.empty(),
}) => Frame(
  id: FrameId(id),
  duration: 12,
  name: 'name-$id',
  strokes: strokes,
  storyboardMetadata: metadata,
);

Stroke _stroke(String id) => Stroke(
  id: StrokeId(id),
  points: const [StrokePoint(x: 1, y: 2)],
  brushSettings: const BrushSettings(),
);

Cut _cutById(Project project, CutId cutId) {
  for (final track in project.tracks) {
    for (final cut in track.cuts) {
      if (cut.id == cutId) return cut;
    }
  }
  throw StateError('Cut not found: $cutId');
}

Layer _layerById(Project project, LayerId layerId) {
  for (final track in project.tracks) {
    for (final cut in track.cuts) {
      for (final layer in cut.layers) {
        if (layer.id == layerId) return layer;
      }
    }
  }
  throw StateError('Layer not found: $layerId');
}
