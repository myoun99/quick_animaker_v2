import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/canvas_viewport.dart';
import '../../models/timesheet_document.dart';
import '../timeline/timeline_drag_preview.dart';
import 'timesheet_document_painter.dart';

/// The timesheet's LIVE drag overlay (UI-R9 #7): while a timeline drag is
/// in flight (comma edge, block move, [+] add, range move), the affected
/// ACTION columns repaint from the PREVIEW layers — light, per-step,
/// through [CustomPainter.repaint] on the session's drag channel — while
/// the full sheet document (and its painter) stays untouched until the
/// release commits. The user rule: "무겁지 않게 글자만 딱 딱" — the
/// overlay covers just the dragged layers' column strips and re-prints
/// their cel numbers/holds/dots/X marks.
///
/// SE columns stand down (their track-global windowing and method-A
/// dialogue layout are the document's job; SE rows already live-update on
/// the timeline).
class TimesheetDragPreviewPainter extends CustomPainter {
  TimesheetDragPreviewPainter({
    required this.document,
    required this.layout,
    required this.dragPreview,
    this.viewport,
  }) : super(repaint: dragPreview);

  final TimesheetDocument document;
  final TimesheetDocumentLayout layout;

  /// The session's scoped drag channel (value-only; never a session
  /// notify) — read at paint time.
  final ValueListenable<TimelineDragPreview?> dragPreview;
  final CanvasViewport? viewport;

  static const Color _paper = Color(0xFFF6F4F0);
  static const Color _ink = Color(0xFF33322F);
  static const Color _gridLight = Color(0xFFCFC9BF);
  static const Color _gridMedium = Color(0xFFA9A296);

  /// The ACTION columns the current preview affects, with cells derived
  /// from the preview layers (the paint source; public as the test
  /// probe).
  List<({int columnIndex, List<TimesheetCell> cells})> previewColumns() {
    final preview = dragPreview.value;
    if (preview == null) {
      return const [];
    }
    final affected = <({int columnIndex, List<TimesheetCell> cells})>[];
    for (var index = 0; index < document.columns.length; index += 1) {
      final column = document.columns[index];
      final layerId = column.layerId;
      if (column.kind != TimesheetColumnKind.action || layerId == null) {
        continue;
      }
      final previewLayer = timelineDragPreviewLayerFor(preview, layerId);
      if (previewLayer == null) {
        continue;
      }
      affected.add((
        columnIndex: index,
        cells: timesheetLayerCells(
          layer: previewLayer,
          rowCount: document.rowCount,
          playbackFrameCount: document.playbackFrameCount,
        ),
      ));
    }
    return affected;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final affected = previewColumns();
    if (affected.isEmpty) {
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final resolvedViewport = viewport;
    if (resolvedViewport != null) {
      canvas.translate(resolvedViewport.panX, resolvedViewport.panY);
      canvas.scale(resolvedViewport.zoom, resolvedViewport.zoom);
    }

    for (final entry in affected) {
      _paintColumn(canvas, entry.columnIndex, entry.cells);
    }
    canvas.restore();
  }

  void _paintColumn(Canvas canvas, int columnIndex, List<TimesheetCell> cells) {
    final width = layout.columnWidthFor(TimesheetColumnKind.action);
    final columnX = layout.columnLeftInHalf(columnIndex);
    const rowHeight = TimesheetDocumentLayout.rowHeight;

    final hairline = Paint()
      ..color = _gridLight
      ..strokeWidth = 1;
    final border = Paint()
      ..color = _gridMedium
      ..strokeWidth = 1;

    // Blank the column's strips first (per page half), then re-print.
    var frame = 0;
    while (frame < document.rowCount) {
      final position = layout.positionOfFrame(frame);
      final rows = layout.continuous
          ? document.rowCount
          : layout.halfRowCount(position.half);
      if (rows <= 0) {
        break;
      }
      final left = layout.halfLeft(position.page, position.half) + columnX;
      final top = layout.frameRowTop(frame);
      final strip = Rect.fromLTWH(left, top, width, rows * rowHeight);
      canvas.drawRect(strip, Paint()..color = _paper);
      // The column's verticals + its row hairlines.
      canvas.drawLine(strip.topLeft, strip.bottomLeft, border);
      canvas.drawLine(strip.topRight, strip.bottomRight, border);
      for (var row = 1; row <= rows; row += 1) {
        final y = top + row * rowHeight;
        canvas.drawLine(Offset(left, y), Offset(left + width, y), hairline);
      }
      frame += rows;
    }

    // The cells: the document painter's ACTION vocabulary, glyphs only.
    for (var row = 0; row < cells.length && row < document.rowCount; row += 1) {
      final cell = cells[row];
      if (cell.kind == TimesheetCellKind.empty) {
        continue;
      }
      final position = layout.positionOfFrame(row);
      final left = layout.halfLeft(position.page, position.half) + columnX;
      final top = layout.frameRowTop(row);
      final centerX = left + width / 2;
      switch (cell.kind) {
        case TimesheetCellKind.drawing:
          _text(canvas, cell.label ?? '', Offset(centerX, top + 3));
        case TimesheetCellKind.held:
          final threshold = document.exposureBarThreshold;
          if (threshold != null && (cell.spanOffset ?? 0) >= threshold) {
            canvas.drawLine(
              Offset(centerX, top),
              Offset(centerX, top + rowHeight),
              Paint()
                ..color = _ink
                ..strokeWidth = 1.0,
            );
          }
        case TimesheetCellKind.mark:
          canvas.drawCircle(
            Offset(centerX, top + rowHeight / 2),
            2.8,
            Paint()..color = _ink,
          );
        case TimesheetCellKind.emptyRunStart:
          _text(canvas, '×', Offset(centerX, top + 2), dim: true);
        case TimesheetCellKind.empty:
        case TimesheetCellKind.cameraKey:
        case TimesheetCellKind.cameraSpan:
        case TimesheetCellKind.instructionStart:
        case TimesheetCellKind.instructionSpan:
        case TimesheetCellKind.instructionEnd:
          break; // Never produced for ACTION columns.
      }
    }
  }

  void _text(Canvas canvas, String text, Offset topCenter, {bool dim = false}) {
    if (text.isEmpty) {
      return;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: dim ? 11 : 10,
          color: dim ? _gridMedium : _ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(topCenter.dx - painter.width / 2, topCenter.dy),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant TimesheetDragPreviewPainter oldDelegate) {
    return !identical(oldDelegate.document, document) ||
        oldDelegate.layout.continuous != layout.continuous ||
        oldDelegate.viewport != viewport;
  }
}
