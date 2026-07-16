import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/timesheet_document.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_drag_preview.dart';
import 'package:quick_animaker_v2/src/ui/timesheet/timesheet_document_painter.dart';
import 'package:quick_animaker_v2/src/ui/timesheet/timesheet_drag_preview_painter.dart';

/// UI-R9 #7: the timesheet's live drag overlay — preview-layer column
/// cells while the document stays stale, cross-layer pairs, and a clean
/// release.
void main() {
  Layer animationLayer(String id, {int length = 2}) => Layer(
    id: LayerId(id),
    name: id.toUpperCase(),
    frames: [Frame(id: FrameId('$id-f1'), duration: 1, strokes: const [])],
    timeline: {
      0: TimelineExposure.drawing(FrameId('$id-f1'), length: length),
    },
  );

  Cut cutWith(List<Layer> layers) => Cut(
    id: const CutId('cut-1'),
    name: '1',
    duration: 12,
    canvasSize: const CanvasSize(width: 1920, height: 1080),
    layers: layers,
  );

  ({
    TimesheetDocument document,
    TimesheetDragPreviewPainter painter,
    ValueNotifier<TimelineDragPreview?> channel,
  })
  fixture(List<Layer> layers) {
    final document = TimesheetDocument.fromCut(
      cut: cutWith(layers),
      projectName: 'P',
      fps: 24,
    );
    final channel = ValueNotifier<TimelineDragPreview?>(null);
    addTearDown(channel.dispose);
    final painter = TimesheetDragPreviewPainter(
      document: document,
      layout: TimesheetDocumentLayout(document: document),
      dragPreview: channel,
    );
    return (document: document, painter: painter, channel: channel);
  }

  test('no drag in flight: no affected columns, paint is a no-op', () {
    final f = fixture([animationLayer('a')]);
    expect(f.painter.previewColumns(), isEmpty);
  });

  test('an edge drag previews ITS column from the preview layer while the '
      'document stays stale', () {
    final f = fixture([animationLayer('a'), animationLayer('b')]);

    // Mid-drag: block a grew 2 → 5.
    f.channel.value = ExposureEdgeDragPreview(
      previewLayer: animationLayer('a', length: 5),
    );

    final affected = f.painter.previewColumns();
    expect(affected, hasLength(1));
    expect(affected.single.columnIndex, 0);
    final cells = affected.single.cells;
    expect(cells[0].kind, TimesheetCellKind.drawing);
    for (var row = 1; row < 5; row += 1) {
      expect(cells[row].kind, TimesheetCellKind.held, reason: 'row $row');
    }
    expect(cells[5].kind, TimesheetCellKind.emptyRunStart);

    // The DOCUMENT still shows the committed length (repo untouched).
    expect(
      f.document.columns[0].cells[2].kind,
      TimesheetCellKind.emptyRunStart,
    );
  });

  test('a cross-layer block move previews BOTH columns', () {
    final f = fixture([animationLayer('a'), animationLayer('b')]);

    f.channel.value = BlockMoveDragPreview(
      previewLayers: {
        const LayerId('a'): Layer(
          id: const LayerId('a'),
          name: 'A',
          frames: const [],
          timeline: const {},
        ),
        const LayerId('b'): Layer(
          id: const LayerId('b'),
          name: 'B',
          frames: [
            Frame(id: const FrameId('a-f1'), duration: 1, strokes: const []),
            Frame(id: const FrameId('b-f1'), duration: 1, strokes: const []),
          ],
          timeline: {
            0: const TimelineExposure.drawing(FrameId('b-f1'), length: 2),
            4: const TimelineExposure.drawing(FrameId('a-f1'), length: 2),
          },
        ),
      },
    );

    final affected = f.painter.previewColumns();
    expect(affected, hasLength(2));
    expect(affected[0].columnIndex, 0);
    expect(affected[1].columnIndex, 1);
    // The emptied source column shows one X run.
    expect(affected[0].cells[0].kind, TimesheetCellKind.emptyRunStart);
    // The target column carries the landed block at 4.
    expect(affected[1].cells[4].kind, TimesheetCellKind.drawing);
    expect(affected[1].cells[5].kind, TimesheetCellKind.held);
  });

  test('release clears the channel: the overlay stands down', () {
    final f = fixture([animationLayer('a')]);
    f.channel.value = ExposureEdgeDragPreview(
      previewLayer: animationLayer('a', length: 4),
    );
    expect(f.painter.previewColumns(), isNotEmpty);

    f.channel.value = null;
    expect(f.painter.previewColumns(), isEmpty);
  });

  test('SE and unbacked columns stand down (ACTION scope only)', () {
    final seLayer = Layer(
      id: const LayerId('se-1'),
      name: 'S1',
      kind: LayerKind.se,
      frames: [
        Frame(id: const FrameId('se-f1'), duration: 2, strokes: const []),
      ],
      timeline: {
        0: const TimelineExposure.drawing(FrameId('se-f1'), length: 2),
      },
    );
    final f = fixture([animationLayer('a'), seLayer]);

    f.channel.value = ExposureEdgeDragPreview(
      previewLayer: seLayer.copyWith(
        timeline: {
          0: const TimelineExposure.drawing(FrameId('se-f1'), length: 5),
        },
      ),
    );

    expect(f.painter.previewColumns(), isEmpty);
  });

  test('the preview dots ride into the overlay cells (block-owned ●)', () {
    final f = fixture([animationLayer('a')]);
    f.channel.value = ExposureEdgeDragPreview(
      previewLayer: Layer(
        id: const LayerId('a'),
        name: 'A',
        frames: [
          Frame(id: const FrameId('a-f1'), duration: 1, strokes: const []),
        ],
        timeline: {
          0: const TimelineExposure.drawing(
            FrameId('a-f1'),
            length: 3,
            breakdownOffsets: [1],
          ),
        },
      ),
    );

    final cells = f.painter.previewColumns().single.cells;
    expect(cells[1].kind, TimesheetCellKind.mark);
    expect(cells[2].kind, TimesheetCellKind.held);
  });
}
