import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/timesheet_document.dart';
import 'package:quick_animaker_v2/src/ui/timesheet/timesheet_document_painter.dart';

TimesheetDocument _document({int duration = 150}) {
  return TimesheetDocument.fromCut(
    cut: Cut(
      id: const CutId('cut-1'),
      name: 'Cut 1',
      layers: const [],
      duration: duration,
      canvasSize: const CanvasSize(width: 1280, height: 720),
    ),
    projectName: 'Project',
    fps: 24,
  );
}

void main() {
  group('TimesheetDocumentLayout continuous mode', () {
    test('keeps the paged paper width and header geometry (user rule: the '
        'view toggle never resizes the paper)', () {
      final document = _document();
      final paged = TimesheetDocumentLayout(document: document);
      final continuous = TimesheetDocumentLayout(
        document: document,
        continuous: true,
      );

      expect(continuous.paperWidth, paged.paperWidth);

      final pagedRect = paged.pageRect(0);
      final continuousRect = continuous.pageRect(0);
      expect(continuousRect.left, pagedRect.left);
      expect(continuousRect.top, pagedRect.top);
      expect(continuousRect.width, pagedRect.width);
    });

    test('only the body below the header changes: one strip in page half '
        '0\'s geometry, extending with the row count', () {
      final document = _document();
      final paged = TimesheetDocumentLayout(document: document);
      final continuous = TimesheetDocumentLayout(
        document: document,
        continuous: true,
      );

      expect(continuous.halfLeft(0, 0), paged.halfLeft(0, 0));
      expect(continuous.halfRowsTop(0), paged.halfRowsTop(0));
      expect(
        continuous.paperHeight,
        greaterThan(paged.paperHeight),
        reason: 'the 288-row strip runs down a single page block',
      );
      expect(continuous.positionOfFrame(200), (page: 0, half: 0, row: 200));
      expect(
        continuous.frameRowTop(1) - continuous.frameRowTop(0),
        TimesheetDocumentLayout.rowHeight,
      );
    });
  });

  group('TimesheetDocumentLayout memo band', () {
    test('sits under the header band and pushes the rows down', () {
      final layout = TimesheetDocumentLayout(document: _document());

      final band = layout.memoBandRect(0);
      final page = layout.pageRect(0);
      expect(
        band.top,
        page.top +
            TimesheetDocumentLayout.pagePadding +
            TimesheetDocumentLayout.headerBandHeight,
      );
      expect(band.height, TimesheetDocumentLayout.memoBandHeight);
      expect(
        layout.halfRowsTop(0),
        band.bottom +
            TimesheetDocumentLayout.headerGap +
            layout.columnsHeaderHeight,
      );
    });
  });

  group('TimesheetDocumentLayout cut-end line', () {
    test('lands at the bottom edge of the last playback frame row', () {
      final layout = TimesheetDocumentLayout(document: _document());

      // duration 150 → last frame 149 = page 1, half 0, row 5.
      final line = layout.cutEndLine;
      expect(line.page, 1);
      expect(line.half, 0);
      expect(
        line.y,
        layout.halfRowsTop(1) + 6 * TimesheetDocumentLayout.rowHeight,
      );
    });

    test('spans into the second half and closes a full half cleanly', () {
      final second = TimesheetDocumentLayout(
        document: _document(duration: 100),
      );
      // last frame 99 → half 1, row 27.
      expect(second.cutEndLine.half, 1);
      expect(
        second.cutEndLine.y,
        second.halfRowsTop(0) + 28 * TimesheetDocumentLayout.rowHeight,
      );

      final boundary = TimesheetDocumentLayout(
        document: _document(duration: 72),
      );
      // exactly one half used → the line closes half 0's bottom.
      expect(boundary.cutEndLine.half, 0);
      expect(
        boundary.cutEndLine.y,
        boundary.halfRowsTop(0) + 72 * TimesheetDocumentLayout.rowHeight,
      );
    });

    test('continuous mode maps it onto the single strip', () {
      final layout = TimesheetDocumentLayout(
        document: _document(),
        continuous: true,
      );

      expect(layout.cutEndLine.page, 0);
      expect(layout.cutEndLine.half, 0);
      expect(
        layout.cutEndLine.y,
        layout.halfRowsTop(0) + 150 * TimesheetDocumentLayout.rowHeight,
      );
    });
  });
}
