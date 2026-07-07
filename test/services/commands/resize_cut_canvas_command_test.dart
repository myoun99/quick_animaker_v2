import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command_id.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_resize_anchor.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';
import 'package:quick_animaker_v2/src/services/commands/resize_cut_canvas_command.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';

void main() {
  group('ResizeCutCanvasCommand', () {
    test('resizes only the target cut canvas', () {
      final repository = _repository();

      ResizeCutCanvasCommand(
        repository: repository,
        cutId: const CutId('cut-target'),
        canvasSize: const CanvasSize(width: 640, height: 480),
      ).execute();

      final cuts = repository.requireProject().tracks.single.cuts;
      expect(cuts.first.canvasSize, const CanvasSize(width: 640, height: 480));
      expect(cuts.first.id, const CutId('cut-target'));
      expect(cuts.first.layers, _targetCut.layers);
      expect(cuts.first.duration, _targetCut.duration);
      expect(cuts.last, _otherCut);
    });

    test('undo restores the previous canvas size', () {
      final repository = _repository();
      final historyManager = HistoryManager();

      historyManager.execute(
        ResizeCutCanvasCommand(
          repository: repository,
          cutId: const CutId('cut-target'),
          canvasSize: const CanvasSize(width: 640, height: 480),
        ),
      );
      historyManager.undo();

      expect(repository.requireProject().tracks.single.cuts.first, _targetCut);
    });

    test('redo applies the new canvas size again', () {
      final repository = _repository();
      final historyManager = HistoryManager();

      historyManager.execute(
        ResizeCutCanvasCommand(
          repository: repository,
          cutId: const CutId('cut-target'),
          canvasSize: const CanvasSize(width: 640, height: 480),
        ),
      );
      historyManager.undo();
      historyManager.redo();

      expect(
        repository.requireProject().tracks.single.cuts.first.canvasSize,
        const CanvasSize(width: 640, height: 480),
      );
    });

    test('throws when undo is called before execute', () {
      final command = ResizeCutCanvasCommand(
        repository: _repository(),
        cutId: const CutId('cut-target'),
        canvasSize: const CanvasSize(width: 640, height: 480),
      );

      expect(command.undo, throwsStateError);
    });

    test('throws when the target cut id is missing', () {
      final command = ResizeCutCanvasCommand(
        repository: _repository(),
        cutId: const CutId('missing'),
        canvasSize: const CanvasSize(width: 640, height: 480),
      );

      expect(command.execute, throwsStateError);
    });
  });

  group('anchored stroke translation', () {
    // Target cut: 1920x1080. Resizing to 1720x880 shrinks by 200x200.
    const shrunkenSize = CanvasSize(width: 1720, height: 880);

    ResizeCutCanvasCommand command({
      required ProjectRepository repository,
      required BrushFrameStore store,
      required CanvasResizeAnchor anchor,
    }) {
      return ResizeCutCanvasCommand(
        repository: repository,
        cutId: const CutId('cut-target'),
        canvasSize: shrunkenSize,
        anchor: anchor,
        brushFrameStore: store,
      );
    }

    test('center anchor shifts strokes by half the size delta', () {
      final store = _storeWithDabAt(x: 500, y: 400);
      command(
        repository: _repository(),
        store: store,
        anchor: CanvasResizeAnchor.center,
      ).execute();

      expect(_dabCenter(store), CanvasPoint(x: 400, y: 300));
    });

    test('bottom-right anchor shifts strokes by the full size delta', () {
      final store = _storeWithDabAt(x: 500, y: 400);
      command(
        repository: _repository(),
        store: store,
        anchor: CanvasResizeAnchor.bottomRight,
      ).execute();

      expect(_dabCenter(store), CanvasPoint(x: 300, y: 200));
    });

    test('top-left anchor leaves stroke coordinates untouched', () {
      final store = _storeWithDabAt(x: 500, y: 400);
      command(
        repository: _repository(),
        store: store,
        anchor: CanvasResizeAnchor.topLeft,
      ).execute();

      expect(_dabCenter(store), CanvasPoint(x: 500, y: 400));
    });

    test('undo and redo restore stroke coordinates exactly', () {
      final store = _storeWithDabAt(x: 500, y: 400);
      final repository = _repository();
      final historyManager = HistoryManager();

      historyManager.execute(
        command(
          repository: repository,
          store: store,
          anchor: CanvasResizeAnchor.center,
        ),
      );
      historyManager.undo();

      expect(_dabCenter(store), CanvasPoint(x: 500, y: 400));
      expect(repository.requireProject().tracks.single.cuts.first, _targetCut);

      historyManager.redo();
      expect(_dabCenter(store), CanvasPoint(x: 400, y: 300));
    });

    test('other cuts strokes are not translated', () {
      final store = BrushFrameStore();
      store.addLivePaintCommand(
        _frameKey(cutId: 'cut-other'),
        _paintCommandWithDabAt(x: 500, y: 400),
      );

      command(
        repository: _repository(),
        store: store,
        anchor: CanvasResizeAnchor.center,
      ).execute();

      final state = store.frameOrNull(_frameKey(cutId: 'cut-other'))!;
      expect(
        state.paintCommands.single.sourceDabs.single.center,
        CanvasPoint(x: 500, y: 400),
      );
    });
  });
}

BrushFrameKey _frameKey({String cutId = 'cut-target'}) => BrushFrameKey(
  projectId: const ProjectId('project-1'),
  trackId: const TrackId('track-1'),
  cutId: CutId(cutId),
  layerId: const LayerId('layer-1'),
  frameId: const FrameId('frame-1'),
);

BrushPaintCommand _paintCommandWithDabAt({
  required double x,
  required double y,
}) {
  return BrushPaintCommand(
    id: const BrushPaintCommandId('paint-1'),
    sequenceNumber: 1,
    kind: BrushPaintCommandKind.paintStroke,
    sourceDabs: [
      BrushDab(
        center: CanvasPoint(x: x, y: y),
        color: 0xFF000000,
        size: 2,
        opacity: 1,
        flow: 1,
        hardness: 1,
        tipShape: BrushTipShape.round,
        pressure: 1,
        sequence: 0,
      ),
    ],
  );
}

BrushFrameStore _storeWithDabAt({required double x, required double y}) {
  return BrushFrameStore()
    ..addLivePaintCommand(_frameKey(), _paintCommandWithDabAt(x: x, y: y));
}

CanvasPoint _dabCenter(BrushFrameStore store) => store
    .frameOrNull(_frameKey())!
    .paintCommands
    .single
    .sourceDabs
    .single
    .center;

final _targetCut = Cut(
  id: const CutId('cut-target'),
  name: 'Target',
  layers: const [],
  duration: 24,
  canvasSize: const CanvasSize(width: 1920, height: 1080),
);

final _otherCut = Cut(
  id: const CutId('cut-other'),
  name: 'Other',
  layers: const [],
  duration: 24,
  canvasSize: const CanvasSize(width: 1280, height: 720),
);

ProjectRepository _repository() {
  return ProjectRepository(
    initialProject: Project(
      id: const ProjectId('project-1'),
      name: 'Project',
      tracks: [
        Track(
          id: const TrackId('track-1'),
          name: 'Video',
          cuts: [_targetCut, _otherCut],
        ),
      ],
      createdAt: DateTime.utc(2024),
    ),
  );
}
