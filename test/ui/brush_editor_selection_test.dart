import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_editor_selection.dart';

void main() {
  test('converts active editor selection to BrushFrameKey', () {
    const selection = BrushEditorSelection(
      projectId: ProjectId('project-active'),
      trackId: TrackId('track-active'),
      cutId: CutId('cut-active'),
      layerId: LayerId('layer-active'),
      frameId: FrameId('frame-active'),
    );

    final key = selection.toBrushFrameKey();

    expect(key.projectId, selection.projectId);
    expect(key.trackId, selection.trackId);
    expect(key.cutId, selection.cutId);
    expect(key.layerId, selection.layerId);
    expect(key.frameId, selection.frameId);
  });
}
