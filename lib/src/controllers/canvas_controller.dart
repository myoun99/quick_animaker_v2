import 'package:flutter/widgets.dart';

import '../models/brush_settings.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/stroke.dart';
import '../models/stroke_id.dart';
import '../models/stroke_point.dart';
import '../services/commands/add_stroke_command.dart';
import '../services/history_manager.dart';
import '../services/project_repository.dart';

class CanvasController {
  CanvasController({
    required ProjectRepository repository,
    required HistoryManager historyManager,
    required FrameId frameId,
    BrushSettings brushSettings = const BrushSettings(),
  }) : _repository = repository,
       _historyManager = historyManager,
       _frameId = frameId,
       _brushSettings = brushSettings;

  final ProjectRepository _repository;
  final HistoryManager _historyManager;
  final FrameId _frameId;
  final BrushSettings _brushSettings;
  final List<StrokePoint> _activePoints = <StrokePoint>[];

  int _strokeSequence = 0;

  List<Stroke> get strokes => _findFrame()?.strokes ?? const <Stroke>[];

  List<StrokePoint> get activePoints => List.unmodifiable(_activePoints);

  bool get canUndo => _historyManager.canUndo;

  bool get canRedo => _historyManager.canRedo;

  void beginStroke(Offset position) {
    _activePoints
      ..clear()
      ..add(_pointFromOffset(position));
  }

  void updateStroke(Offset position) {
    if (_activePoints.isEmpty) {
      beginStroke(position);
      return;
    }

    _activePoints.add(_pointFromOffset(position));
  }

  void endStroke() {
    if (_activePoints.length < 2) {
      _activePoints.clear();
      return;
    }

    final stroke = Stroke(
      id: StrokeId(_nextStrokeId()),
      points: List<StrokePoint>.unmodifiable(_activePoints),
      brushSettings: _brushSettings,
    );

    _historyManager.execute(
      AddStrokeCommand(
        repository: _repository,
        frameId: _frameId,
        stroke: stroke,
      ),
    );
    _activePoints.clear();
  }

  void cancelStroke() {
    _activePoints.clear();
  }

  void undo() {
    if (canUndo) {
      _historyManager.undo();
    }
  }

  void redo() {
    if (canRedo) {
      _historyManager.redo();
    }
  }

  StrokePoint _pointFromOffset(Offset position) {
    return StrokePoint(x: position.dx, y: position.dy);
  }

  String _nextStrokeId() {
    _strokeSequence += 1;
    return 'stroke-${DateTime.now().microsecondsSinceEpoch}-$_strokeSequence';
  }

  Frame? _findFrame() {
    final project = _repository.currentProject;
    if (project == null) {
      return null;
    }

    for (final track in project.tracks) {
      for (final cut in track.cuts) {
        for (final layer in cut.layers) {
          for (final frame in layer.frames) {
            if (frame.id == _frameId) {
              return frame;
            }
          }
        }
      }
    }

    return null;
  }
}
