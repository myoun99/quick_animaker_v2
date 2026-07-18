import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/timeline_repeat.dart';
import 'package:quick_animaker_v2/src/models/timesheet_document.dart';

/// UI-R24 #1: the DATA sheet — the timesheet's export-source view. Ghost
/// chains render VERBATIM (the per-entry labels XDTS/TDTS write) instead
/// of the notation shorthand; holds stay holds (labels never tile down
/// held rows).
Layer _repeatLayer() {
  var layer = Layer(
    id: const LayerId('a'),
    name: 'A',
    frames: [
      Frame(id: const FrameId('c1'), name: '1', duration: 1, strokes: const []),
      Frame(id: const FrameId('c2'), name: '2', duration: 1, strokes: const []),
    ],
    timeline: const {
      0: TimelineExposure.drawing(FrameId('c1'), length: 2),
      2: TimelineExposure.drawing(FrameId('c2'), length: 2),
    },
    runBehaviors: const [
      TimelineRunBehavior(
        anchorFrameId: FrameId('c1'),
        side: TimelineRunEdgeSide.end,
        mode: TimelineRunEdgeMode.repeat,
      ),
    ],
  );
  layer = rederiveRunBehaviors(layer, cutFrameCount: 12);
  return layer;
}

TimesheetDocument _document(Layer layer, {required bool dataSheet}) {
  return TimesheetDocument.fromCut(
    cut: Cut(
      id: const CutId('cut-1'),
      name: 'Cut 1',
      layers: [layer],
      duration: 12,
      canvasSize: const CanvasSize(width: 1280, height: 720),
    ),
    projectName: 'Project',
    fps: 24,
    dataSheet: dataSheet,
  );
}

void main() {
  test('a rear repeat prints the NOTATION word normally and the VERBATIM '
      'export labels in DATA mode — holds stay holds, never tiled', () {
    final layer = _repeatLayer();
    // The derived timeline: 1(2) 2(2) then repeat ghosts 1(2) 2(2)…
    expect(layer.timeline[4]!.ghost, isTrue);

    final notation = _document(layer, dataSheet: false).columns.first.cells;
    expect(notation[0].kind, TimesheetCellKind.drawing);
    expect(notation[0].label, '1');
    expect(notation[4].kind, TimesheetCellKind.repeatStart);
    expect(notation[5].kind, TimesheetCellKind.repeatSpan);

    final data = _document(layer, dataSheet: true).columns.first.cells;
    // The authored blocks are untouched…
    expect(data[0].kind, TimesheetCellKind.drawing);
    expect(data[0].label, '1');
    expect(data[2].label, '2');
    // …and the ghost chain prints its concrete per-entry labels exactly
    // where XDTS writes its value changes.
    expect(data[4].kind, TimesheetCellKind.drawing);
    expect(data[4].label, '1');
    expect(data[6].kind, TimesheetCellKind.drawing);
    expect(data[6].label, '2');
    expect(data[8].label, '1');
    expect(data[10].label, '2');
    // Held rows remain HELD — the label never tiles down the hold.
    expect(data[1].kind, TimesheetCellKind.held);
    expect(data[5].kind, TimesheetCellKind.held);
  });

  test('a rear HOLD (止め) prints the hold word normally and ONE verbatim '
      'label at the ghost start in DATA mode', () {
    var layer = Layer(
      id: const LayerId('h'),
      name: 'H',
      frames: [
        Frame(
          id: const FrameId('cel'),
          name: '1',
          duration: 1,
          strokes: const [],
        ),
      ],
      timeline: const {
        0: TimelineExposure.drawing(FrameId('cel'), length: 2),
      },
      runBehaviors: const [
        TimelineRunBehavior(
          anchorFrameId: FrameId('cel'),
          side: TimelineRunEdgeSide.end,
          mode: TimelineRunEdgeMode.hold,
        ),
      ],
    );
    layer = rederiveRunBehaviors(layer, cutFrameCount: 12);
    expect(layer.timeline[2]!.ghost, isTrue);

    final notation = _document(layer, dataSheet: false).columns.first.cells;
    expect(notation[2].kind, TimesheetCellKind.holdStart);

    final data = _document(layer, dataSheet: true).columns.first.cells;
    // One drawing label at the hold ghost's start (the XDTS value-change
    // row), then plain held rows to the cut end — no label tiling.
    expect(data[2].kind, TimesheetCellKind.drawing);
    expect(data[2].label, '1');
    for (var row = 3; row < 12; row += 1) {
      expect(data[row].kind, TimesheetCellKind.held, reason: 'row $row');
    }
  });
}
