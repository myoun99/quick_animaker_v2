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
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/commands/update_storyboard_frame_metadata_command.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';

void main() {
  group('UpdateStoryboardFrameMetadataCommand', () {
    test('execute updates metadata and preserves target contents', () {
      final stroke = _stroke('stroke-1');
      final targetFrame = _frame(id: 'frame-target', strokes: [stroke]);
      final targetLayer = _layer(
        id: 'layer-target',
        kind: LayerKind.storyboard,
        frames: [targetFrame],
        isVisible: false,
        opacity: 0.5,
      );
      final targetCut = _cut(
        id: 'cut-target',
        layers: [targetLayer],
        metadata: const CutMetadata(note: 'Cut note'),
      );
      final repository = ProjectRepository(
        initialProject: _project([targetCut]),
      );
      const metadata = StoryboardFrameMetadata(
        actionMemo: 'Run to door',
        dialogueMemo: 'A: Wait!',
        note: 'Panel note',
      );

      UpdateStoryboardFrameMetadataCommand(
        repository: repository,
        cutId: targetCut.id,
        layerId: targetLayer.id,
        frameId: targetFrame.id,
        metadata: metadata,
      ).execute();

      final updatedCut = _cutById(repository.requireProject(), targetCut.id);
      final updatedLayer = updatedCut.layers.single;
      final updatedFrame = updatedLayer.frames.single;
      expect(updatedFrame.storyboardMetadata, metadata);
      expect(updatedFrame.id, targetFrame.id);
      expect(updatedFrame.duration, targetFrame.duration);
      expect(updatedFrame.name, targetFrame.name);
      expect(updatedFrame.strokes, [stroke]);
      expect(updatedLayer.kind, LayerKind.storyboard);
      expect(updatedLayer.isVisible, isFalse);
      expect(updatedLayer.opacity, 0.5);
      expect(updatedCut.metadata, const CutMetadata(note: 'Cut note'));
    });

    test('undo restores previous metadata', () {
      final targetFrame = _frame(
        id: 'frame-target',
        metadata: const StoryboardFrameMetadata(note: 'Old'),
      );
      final targetLayer = _layer(
        id: 'layer-target',
        kind: LayerKind.storyboard,
        frames: [targetFrame],
      );
      final targetCut = _cut(id: 'cut-target', layers: [targetLayer]);
      final repository = ProjectRepository(
        initialProject: _project([targetCut]),
      );
      final historyManager = HistoryManager();

      historyManager.execute(
        UpdateStoryboardFrameMetadataCommand(
          repository: repository,
          cutId: targetCut.id,
          layerId: targetLayer.id,
          frameId: targetFrame.id,
          metadata: const StoryboardFrameMetadata(note: 'New'),
        ),
      );
      historyManager.undo();

      expect(
        _frameById(
          repository.requireProject(),
          targetFrame.id,
        ).storyboardMetadata,
        const StoryboardFrameMetadata(note: 'Old'),
      );
    });

    test('redo reapplies metadata', () {
      final targetFrame = _frame(id: 'frame-target');
      final targetLayer = _layer(
        id: 'layer-target',
        kind: LayerKind.storyboard,
        frames: [targetFrame],
      );
      final targetCut = _cut(id: 'cut-target', layers: [targetLayer]);
      final repository = ProjectRepository(
        initialProject: _project([targetCut]),
      );
      final historyManager = HistoryManager();
      const metadata = StoryboardFrameMetadata(actionMemo: 'New action');

      historyManager.execute(
        UpdateStoryboardFrameMetadataCommand(
          repository: repository,
          cutId: targetCut.id,
          layerId: targetLayer.id,
          frameId: targetFrame.id,
          metadata: metadata,
        ),
      );
      historyManager.undo();
      historyManager.redo();

      expect(
        _frameById(
          repository.requireProject(),
          targetFrame.id,
        ).storyboardMetadata,
        metadata,
      );
    });

    test('replacing existing metadata works and undo restores it', () {
      const oldMetadata = StoryboardFrameMetadata(actionMemo: 'Old');
      const newMetadata = StoryboardFrameMetadata(
        actionMemo: 'New',
        dialogueMemo: 'Line',
        note: 'Note',
      );
      final targetFrame = _frame(id: 'frame-target', metadata: oldMetadata);
      final targetLayer = _layer(
        id: 'layer-target',
        kind: LayerKind.storyboard,
        frames: [targetFrame],
      );
      final targetCut = _cut(id: 'cut-target', layers: [targetLayer]);
      final repository = ProjectRepository(
        initialProject: _project([targetCut]),
      );
      final historyManager = HistoryManager();

      historyManager.execute(
        UpdateStoryboardFrameMetadataCommand(
          repository: repository,
          cutId: targetCut.id,
          layerId: targetLayer.id,
          frameId: targetFrame.id,
          metadata: newMetadata,
        ),
      );

      expect(
        _frameById(
          repository.requireProject(),
          targetFrame.id,
        ).storyboardMetadata,
        newMetadata,
      );

      historyManager.undo();

      expect(
        _frameById(
          repository.requireProject(),
          targetFrame.id,
        ).storyboardMetadata,
        oldMetadata,
      );
    });

    test('missing targets throw StateError', () {
      final targetFrame = _frame(id: 'frame-target');
      final targetLayer = _layer(
        id: 'layer-target',
        kind: LayerKind.storyboard,
        frames: [targetFrame],
      );
      final targetCut = _cut(id: 'cut-target', layers: [targetLayer]);
      final repository = ProjectRepository(
        initialProject: _project([targetCut]),
      );

      expect(
        () => UpdateStoryboardFrameMetadataCommand(
          repository: repository,
          cutId: const CutId('missing'),
          layerId: targetLayer.id,
          frameId: targetFrame.id,
          metadata: const StoryboardFrameMetadata(note: 'New'),
        ).execute(),
        throwsStateError,
      );
      expect(
        () => UpdateStoryboardFrameMetadataCommand(
          repository: repository,
          cutId: targetCut.id,
          layerId: const LayerId('missing'),
          frameId: targetFrame.id,
          metadata: const StoryboardFrameMetadata(note: 'New'),
        ).execute(),
        throwsStateError,
      );
      expect(
        () => UpdateStoryboardFrameMetadataCommand(
          repository: repository,
          cutId: targetCut.id,
          layerId: targetLayer.id,
          frameId: const FrameId('missing'),
          metadata: const StoryboardFrameMetadata(note: 'New'),
        ).execute(),
        throwsStateError,
      );
    });

    test('animation layer is rejected without mutation', () {
      final targetFrame = _frame(id: 'frame-target');
      final targetLayer = _layer(
        id: 'layer-target',
        kind: LayerKind.animation,
        frames: [targetFrame],
      );
      final targetCut = _cut(id: 'cut-target', layers: [targetLayer]);
      final repository = ProjectRepository(
        initialProject: _project([targetCut]),
      );
      final beforeJson = repository.requireProject().toJson();

      expect(
        () => UpdateStoryboardFrameMetadataCommand(
          repository: repository,
          cutId: targetCut.id,
          layerId: targetLayer.id,
          frameId: targetFrame.id,
          metadata: const StoryboardFrameMetadata(note: 'New'),
        ).execute(),
        throwsStateError,
      );
      expect(repository.requireProject().toJson(), beforeJson);
    });

    test('unrelated cuts layers frames and strokes are preserved', () {
      final targetFrame = _frame(id: 'frame-target', strokes: [_stroke('s1')]);
      final otherFrame = _frame(id: 'frame-other', strokes: [_stroke('s2')]);
      final targetLayer = _layer(
        id: 'layer-target',
        kind: LayerKind.storyboard,
        frames: [targetFrame, otherFrame],
      );
      final otherLayer = _layer(
        id: 'layer-other',
        frames: [_frame(id: 'frame-3')],
      );
      final targetCut = _cut(
        id: 'cut-target',
        layers: [targetLayer, otherLayer],
      );
      final otherCut = _cut(
        id: 'cut-other',
        layers: [_layer(id: 'layer-4')],
      );
      final repository = ProjectRepository(
        initialProject: _project([targetCut, otherCut]),
      );

      UpdateStoryboardFrameMetadataCommand(
        repository: repository,
        cutId: targetCut.id,
        layerId: targetLayer.id,
        frameId: targetFrame.id,
        metadata: const StoryboardFrameMetadata(note: 'New'),
      ).execute();

      final updatedTargetCut = _cutById(
        repository.requireProject(),
        targetCut.id,
      );
      expect(updatedTargetCut.layers[1], otherLayer);
      expect(updatedTargetCut.layers.first.frames[1], otherFrame);
      expect(_cutById(repository.requireProject(), otherCut.id), otherCut);
      expect(
        updatedTargetCut.layers.first.frames.first.strokes,
        targetFrame.strokes,
      );
    });
  });
}

Project _project(List<Cut> cuts) => Project(
  id: const ProjectId('project-1'),
  name: 'Project',
  tracks: [Track(id: const TrackId('track-1'), name: 'Video', cuts: cuts)],
  createdAt: DateTime.utc(2026, 6, 11),
);

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
  LayerKind kind = LayerKind.animation,
  bool isVisible = true,
  double opacity = 1.0,
}) => Layer(
  id: LayerId(id),
  name: id,
  frames: frames,
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
  brushSettings: BrushSettings(),
);

Cut _cutById(Project project, CutId cutId) {
  for (final track in project.tracks) {
    for (final cut in track.cuts) {
      if (cut.id == cutId) return cut;
    }
  }
  throw StateError('Cut not found: $cutId');
}

Frame _frameById(Project project, FrameId frameId) {
  for (final track in project.tracks) {
    for (final cut in track.cuts) {
      for (final layer in cut.layers) {
        for (final frame in layer.frames) {
          if (frame.id == frameId) return frame;
        }
      }
    }
  }
  throw StateError('Frame not found: $frameId');
}
