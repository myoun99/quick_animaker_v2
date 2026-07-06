import '../../models/canvas_resize_anchor.dart';
import '../../models/canvas_size.dart';
import '../../models/cut_id.dart';
import '../../models/project.dart';
import '../brush_frame_store.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';

class ResizeCutCanvasCommand implements Command {
  ResizeCutCanvasCommand({
    required this.repository,
    required this.cutId,
    required this.canvasSize,
    this.anchor = CanvasResizeAnchor.topLeft,
    this.brushFrameStore,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final CanvasSize canvasSize;
  final CanvasResizeAnchor anchor;

  /// When set, the cut's brush strokes are shifted so the artwork stays
  /// pinned to [anchor] (the project model only stores the cut size; stroke
  /// data lives in the app-level brush store).
  final BrushFrameStore? brushFrameStore;

  Project? _previousProject;
  double _contentDx = 0;
  double _contentDy = 0;

  @override
  String get description =>
      'Resize canvas to ${canvasSize.width}x${canvasSize.height}';

  @override
  void execute() {
    final project = repository.requireProject();
    _previousProject = project;

    final offset = anchor.contentOffset(
      from: requireCut(project, cutId).canvasSize,
      to: canvasSize,
    );
    _contentDx = offset.dx;
    _contentDy = offset.dy;

    repository.updateCutCanvasSize(cutId: cutId, canvasSize: canvasSize);
    brushFrameStore?.translateCutContent(
      cutId: cutId,
      dx: _contentDx,
      dy: _contentDy,
    );
  }

  @override
  void undo() {
    final previousProject = _previousProject;
    if (previousProject == null) {
      throw StateError('Command has not been executed.');
    }

    repository.replaceProject(previousProject);
    brushFrameStore?.translateCutContent(
      cutId: cutId,
      dx: -_contentDx,
      dy: -_contentDy,
    );
  }
}
