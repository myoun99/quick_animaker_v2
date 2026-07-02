import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_cut_helpers.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_canvas_defaults.dart';

void main() {
  test('Project defaults to the Brush T2 camera size', () {
    final project = Project(
      id: const ProjectId('project'),
      name: 'Project',
      tracks: const [],
      createdAt: DateTime.utc(2026),
    );

    expect(project.cameraSize, const CanvasSize(width: 1920, height: 1080));
  });

  test('default Cut and production brush canvas use the Brush T2 canvas size', () {
    final cut = createDefaultCut(
      cutId: const CutId('cut'),
      name: 'Cut',
      layerId: const LayerId('layer'),
    );

    expect(defaultCutCanvasSize, const CanvasSize(width: 2340, height: 1654));
    expect(cut.canvasSize, const CanvasSize(width: 2340, height: 1654));
    expect(
      BrushCanvasDefaults.canvasSize,
      const CanvasSize(width: 2340, height: 1654),
    );
  });
}
