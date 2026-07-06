import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
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
}

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
