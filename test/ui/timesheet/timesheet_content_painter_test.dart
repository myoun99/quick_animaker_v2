import 'package:flutter/material.dart';
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
import 'package:quick_animaker_v2/src/ui/timeline/timeline_drag_preview.dart';
import 'package:quick_animaker_v2/src/ui/timesheet/timesheet_document_painter.dart';

/// UI-R10 #9: the sheet paints in two strata — the CONTENT stratum
/// substitutes in-flight drag previews per ACTION column (the UI-R9
/// patch overlay, replaced) — plus the sheet's ghost display rules
/// (#6/#11) and the CELL header mirror (#10).
void main() {
  Layer animationLayer(String id, {int length = 2}) => Layer(
    id: LayerId(id),
    name: id.toUpperCase(),
    frames: [Frame(id: FrameId('$id-f1'), duration: 1, strokes: const [])],
    timeline: {
      0: TimelineExposure.drawing(FrameId('$id-f1'), length: length),
    },
  );

  TimesheetDocument documentFor(List<Layer> layers) => TimesheetDocument.fromCut(
    cut: Cut(
      id: const CutId('cut-1'),
      name: '1',
      duration: 12,
      canvasSize: const CanvasSize(width: 1920, height: 1080),
      layers: layers,
    ),
    projectName: 'P',
    fps: 24,
  );

  TimesheetDocumentPainter contentPainter(
    TimesheetDocument document,
    ValueNotifier<TimelineDragPreview?> channel,
  ) => TimesheetDocumentPainter(
    document: document,
    layout: TimesheetDocumentLayout(document: document),
    paintLayer: TimesheetPaintLayer.content,
    dragPreview: channel,
  );

  test('the content stratum substitutes the drag preview for ITS column '
      'while the document stays stale', () {
    final document = documentFor([animationLayer('a'), animationLayer('b')]);
    final channel = ValueNotifier<TimelineDragPreview?>(null);
    addTearDown(channel.dispose);
    final painter = contentPainter(document, channel);

    // No drag: the document's own cells.
    expect(
      painter.displayCellsFor(document.columns[0])[2].kind,
      TimesheetCellKind.emptyRunStart,
    );

    // Mid-drag: block a grew 2 → 5.
    channel.value = ExposureEdgeDragPreview(
      previewLayer: animationLayer('a', length: 5),
    );
    final cells = painter.displayCellsFor(document.columns[0]);
    expect(cells[0].kind, TimesheetCellKind.drawing);
    for (var row = 1; row < 5; row += 1) {
      expect(cells[row].kind, TimesheetCellKind.held, reason: 'row $row');
    }
    expect(cells[5].kind, TimesheetCellKind.emptyRunStart);
    // The untargeted column and the DOCUMENT stay stale.
    expect(
      painter.displayCellsFor(document.columns[1]),
      same(document.columns[1].cells),
    );
    expect(
      document.columns[0].cells[2].kind,
      TimesheetCellKind.emptyRunStart,
    );

    // Release clears the channel: back to the document.
    channel.value = null;
    expect(
      painter.displayCellsFor(document.columns[0]),
      same(document.columns[0].cells),
    );
  });

  test('a REPEAT ghost chain prints the repeat word once + a guide line, '
      'never the expanded numbers (UI-R10 #6)', () {
    final layer = rederiveRunBehaviors(
      animationLayer('a').copyWith(
        runBehaviors: const [
          TimelineRunBehavior(
            anchorFrameId: FrameId('a-f1'),
            side: TimelineRunEdgeSide.end,
            mode: TimelineRunEdgeMode.repeat,
          ),
        ],
      ),
      cutFrameCount: 8,
    );
    final cells = documentFor([layer]).columns[0].cells;

    expect(cells[2].kind, TimesheetCellKind.repeatStart);
    expect(cells[2].spanLength, 6, reason: 'chain [2,8)');
    for (var row = 3; row < 8; row += 1) {
      expect(cells[row].kind, TimesheetCellKind.repeatSpan, reason: '$row');
    }
    expect(cells[8].kind, TimesheetCellKind.emptyRunStart,
        reason: 'past the chain the X run restarts');
  });

  test('an END hold ghost prints NOTHING; a FRONT hold prints the held '
      'cel on its first row only (UI-R10 #11)', () {
    final endHold = rederiveRunBehaviors(
      animationLayer('a').copyWith(
        runBehaviors: const [
          TimelineRunBehavior(
            anchorFrameId: FrameId('a-f1'),
            side: TimelineRunEdgeSide.end,
            mode: TimelineRunEdgeMode.hold,
          ),
        ],
      ),
      cutFrameCount: 8,
    );
    final endCells = documentFor([endHold]).columns[0].cells;
    for (var row = 2; row < 8; row += 1) {
      expect(endCells[row].kind, TimesheetCellKind.empty, reason: '$row');
    }
    expect(endCells[8].kind, TimesheetCellKind.emptyRunStart,
        reason: 'the ghost coverage suppressed X inside [2,8) only');

    final frontHold = rederiveRunBehaviors(
      Layer(
        id: const LayerId('b'),
        name: 'B',
        frames: [
          Frame(
            id: const FrameId('b-f1'),
            duration: 1,
            name: '5',
            strokes: const [],
          ),
        ],
        timeline: {
          4: const TimelineExposure.drawing(FrameId('b-f1'), length: 2),
        },
        runBehaviors: const [
          TimelineRunBehavior(
            anchorFrameId: FrameId('b-f1'),
            side: TimelineRunEdgeSide.start,
            mode: TimelineRunEdgeMode.hold,
          ),
        ],
      ),
      cutFrameCount: 12,
    );
    final frontCells = documentFor([frontHold]).columns[0].cells;
    expect(frontCells[0].kind, TimesheetCellKind.drawing);
    expect(frontCells[0].label, '5', reason: 'the held cel prints at row 1');
    for (var row = 1; row < 4; row += 1) {
      expect(frontCells[row].kind, TimesheetCellKind.empty, reason: '$row');
    }
    expect(frontCells[4].kind, TimesheetCellKind.drawing);
  });

  test('the CELL block mirrors the ACTION layer names as headers '
      '(UI-R10 #10)', () {
    final document = documentFor([animationLayer('a'), animationLayer('b')]);
    final celColumns = [
      for (final column in document.columns)
        if (column.kind == TimesheetColumnKind.cel) column,
    ];
    expect(celColumns[0].label, 'A');
    expect(celColumns[1].label, 'B');
    expect(celColumns[2].label, '');
    expect(celColumns[0].cells.every((c) => c.kind == TimesheetCellKind.empty),
        isTrue, reason: 'headers only — the content stays blank');
  });
}
