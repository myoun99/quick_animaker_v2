import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_drawing_state.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command_id.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command_state.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';

void main() {
  test(
    'visibleActivePaintCommands excludes hiddenByUndo and orders deferred before live deterministically',
    () {
      final key = BrushFrameKey(
        projectId: ProjectId('p'),
        trackId: TrackId('t'),
        cutId: CutId('c'),
        layerId: LayerId('l'),
        frameId: FrameId('f'),
      );
      final state = BrushFrameDrawingState(
        key: key,
        paintCommands: [
          BrushPaintCommand(
            id: BrushPaintCommandId('3'),
            sequenceNumber: 3,
            kind: BrushPaintCommandKind.paintStroke,
          ),
          BrushPaintCommand(
            id: BrushPaintCommandId('1'),
            sequenceNumber: 1,
            kind: BrushPaintCommandKind.paintStroke,
            state: BrushPaintCommandState.deferredBake,
          ),
          BrushPaintCommand(
            id: BrushPaintCommandId('2'),
            sequenceNumber: 2,
            kind: BrushPaintCommandKind.paintStroke,
            state: BrushPaintCommandState.hiddenByUndo,
          ),
        ],
      );

      expect(state.hasDeferredBakeCommands, isTrue);
      expect(state.deferredBakeCount, 1);
      expect(
        state.visibleActivePaintCommands.map((command) => command.id.value),
        ['1', '3'],
      );
    },
  );
}
