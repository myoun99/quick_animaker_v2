import 'package:flutter/material.dart';

import '../../models/canvas_viewport.dart';
import '../../models/timesheet_document.dart';

/// Geometry of the rendered sheet document in canvas (document) space.
///
/// The document always lays out in page blocks; the continuous mode only
/// drops the gaps and the repeated page headers, so page-anchored content
/// (later: ink annotations) never shifts within its page.
class TimesheetDocumentLayout {
  const TimesheetDocumentLayout({required this.document, this.continuous = false});

  final TimesheetDocument document;
  final bool continuous;

  static const double rowHeight = 18;
  static const double columnWidth = 56;
  static const double railWidth = 32;
  static const double pageHeaderHeight = 56;
  static const double columnHeaderHeight = 26;
  static const double pageMarginX = 18;
  static const double pageBottomPadding = 14;
  static const double pageGap = 28;
  static const double documentMargin = 24;

  double get pageWidth =>
      pageMarginX * 2 + railWidth + document.columns.length * columnWidth;

  double get _rowsHeight => document.pageFrameCount * rowHeight;

  /// One paged block: header + column header + rows + padding.
  double get pageBlockHeight =>
      pageHeaderHeight + columnHeaderHeight + _rowsHeight + pageBottomPadding;

  double get pageLeft => documentMargin;

  /// Top of a page BLOCK (its header in paged mode; its rows region joins
  /// the previous page seamlessly in continuous mode).
  double pageTop(int pageIndex) {
    if (continuous) {
      return documentMargin + pageIndex * _rowsHeight;
    }
    return documentMargin + pageIndex * (pageBlockHeight + pageGap);
  }

  /// Whether this page draws its own header block (paged: all pages;
  /// continuous: only the first).
  bool pageDrawsHeader(int pageIndex) => !continuous || pageIndex == 0;

  /// Top of a page's ROWS region.
  double rowsTop(int pageIndex) {
    if (continuous) {
      return documentMargin +
          pageHeaderHeight +
          columnHeaderHeight +
          pageIndex * _rowsHeight;
    }
    return pageTop(pageIndex) + pageHeaderHeight + columnHeaderHeight;
  }

  /// Top edge of a global frame row (0-based frame index).
  double frameRowTop(int frameIndex) {
    final page = frameIndex ~/ document.pageFrameCount;
    final rowInPage = frameIndex % document.pageFrameCount;
    return rowsTop(page) + rowInPage * rowHeight;
  }

  double columnLeft(int columnIndex) =>
      pageLeft + pageMarginX + railWidth + columnIndex * columnWidth;

  /// Full page rect (block) — the Fit target for page framing.
  Rect pageRect(int pageIndex) {
    final top = continuous && pageIndex > 0
        ? rowsTop(pageIndex)
        : pageTop(pageIndex);
    final bottom = continuous
        ? rowsTop(pageIndex) + _rowsHeight
        : pageTop(pageIndex) + pageBlockHeight;
    return Rect.fromLTRB(pageLeft, top, pageLeft + pageWidth, bottom);
  }

  /// Logical size of the whole document.
  Size get documentSize {
    final pageCount = document.pages.length;
    final double height;
    if (continuous) {
      height =
          documentMargin * 2 +
          pageHeaderHeight +
          columnHeaderHeight +
          pageCount * _rowsHeight +
          pageBottomPadding;
    } else {
      height =
          documentMargin * 2 +
          pageCount * pageBlockHeight +
          (pageCount - 1) * pageGap;
    }
    return Size(documentMargin * 2 + pageWidth, height);
  }
}

/// Paints the sheet document (paper pages, grid, cel numbers, holds, X,
/// camera keys, playhead row) under the panel viewport transform — the same
/// inside-the-picture transform the brush canvas uses, so zooming stays
/// crisp at any scale.
class TimesheetDocumentPainter extends CustomPainter {
  const TimesheetDocumentPainter({
    required this.document,
    required this.layout,
    this.viewport,
    this.playheadFrame,
  });

  final TimesheetDocument document;
  final TimesheetDocumentLayout layout;
  final CanvasViewport? viewport;

  /// Current frame (0-based) highlighted as the sheet's playhead row.
  final int? playheadFrame;

  static const Color _paper = Color(0xFFF5F3EF);
  static const Color _ink = Color(0xFF33322F);
  static const Color _gridLight = Color(0xFFCFC9BF);
  static const Color _gridBold = Color(0xFF8F887B);
  static const Color _playhead = Color(0x334FA8A0);

  /// Below this zoom the per-cell texts stop painting (paper overview).
  static const double _textZoomThreshold = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final resolvedViewport = viewport;
    if (resolvedViewport != null) {
      canvas.translate(resolvedViewport.panX, resolvedViewport.panY);
      canvas.scale(resolvedViewport.zoom, resolvedViewport.zoom);
    }
    final drawTexts = (resolvedViewport?.zoom ?? 1.0) >= _textZoomThreshold;

    for (final page in document.pages) {
      _paintPage(canvas, page, drawTexts: drawTexts);
    }
    _paintPlayhead(canvas);

    canvas.restore();
  }

  void _paintPage(Canvas canvas, TimesheetPage page, {required bool drawTexts}) {
    final pageRect = layout.pageRect(page.index);
    canvas.drawRect(pageRect, Paint()..color = _paper);
    canvas.drawRect(
      pageRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _gridBold,
    );

    if (layout.pageDrawsHeader(page.index)) {
      _paintPageHeader(canvas, page, drawTexts: drawTexts);
      _paintColumnHeader(canvas, page, drawTexts: drawTexts);
    }
    _paintRows(canvas, page, drawTexts: drawTexts);
  }

  void _paintPageHeader(
    Canvas canvas,
    TimesheetPage page, {
    required bool drawTexts,
  }) {
    final top = layout.continuous
        ? TimesheetDocumentLayout.documentMargin
        : layout.pageTop(page.index);
    final left = layout.pageLeft + TimesheetDocumentLayout.pageMarginX;
    final right = layout.pageLeft + layout.pageWidth -
        TimesheetDocumentLayout.pageMarginX;
    final baseline = top + TimesheetDocumentLayout.pageHeaderHeight - 14;

    canvas.drawLine(
      Offset(left, top + TimesheetDocumentLayout.pageHeaderHeight - 6),
      Offset(right, top + TimesheetDocumentLayout.pageHeaderHeight - 6),
      Paint()
        ..color = _gridBold
        ..strokeWidth = 1.2,
    );
    if (!drawTexts) {
      return;
    }

    _text(
      canvas,
      document.projectName,
      Offset(left, baseline - 14),
      fontSize: 12,
      bold: true,
    );
    _text(
      canvas,
      'CUT ${document.cutName}',
      Offset(left, baseline),
      fontSize: 11,
    );
    _text(
      canvas,
      'TIME ${document.durationLabel}',
      Offset(left + 150, baseline),
      fontSize: 11,
    );
    final pageLabel = 'PAGE ${page.index + 1}/${document.pages.length}';
    _text(
      canvas,
      pageLabel,
      Offset(right - 90, baseline),
      fontSize: 11,
    );
  }

  void _paintColumnHeader(
    Canvas canvas,
    TimesheetPage page, {
    required bool drawTexts,
  }) {
    final rowsTop = layout.rowsTop(page.index);
    final headerTop = rowsTop - TimesheetDocumentLayout.columnHeaderHeight;

    if (!drawTexts) {
      return;
    }
    for (var column = 0; column < document.columns.length; column += 1) {
      _text(
        canvas,
        document.columns[column].label,
        Offset(layout.columnLeft(column) + 4, headerTop + 7),
        fontSize: 10,
        bold: document.columns[column].kind != TimesheetColumnKind.cel,
        maxWidth: TimesheetDocumentLayout.columnWidth - 8,
      );
    }
  }

  void _paintRows(Canvas canvas, TimesheetPage page, {required bool drawTexts}) {
    final rowsTop = layout.rowsTop(page.index);
    final rowsBottom =
        rowsTop + page.frameCount * TimesheetDocumentLayout.rowHeight;
    final gridLeft =
        layout.pageLeft + TimesheetDocumentLayout.pageMarginX;
    final gridRight = layout.columnLeft(document.columns.length);

    final lightPaint = Paint()
      ..color = _gridLight
      ..strokeWidth = 0.7;
    final boldPaint = Paint()
      ..color = _gridBold
      ..strokeWidth = 1.3;

    // Horizontal row lines: light per frame, bold on second boundaries
    // (and the top edge).
    for (var row = 0; row <= page.frameCount; row += 1) {
      final globalFrame = page.startFrame + row;
      final y = rowsTop + row * TimesheetDocumentLayout.rowHeight;
      final isSecond = globalFrame % document.fps == 0;
      canvas.drawLine(
        Offset(gridLeft, y),
        Offset(gridRight, y),
        isSecond ? boldPaint : lightPaint,
      );
    }

    // Vertical lines: rail, column separators, heavier at section changes.
    canvas.drawLine(
      Offset(gridLeft, rowsTop),
      Offset(gridLeft, rowsBottom),
      boldPaint,
    );
    for (var column = 0; column <= document.columns.length; column += 1) {
      final x = layout.columnLeft(column);
      final sectionEdge =
          column == 0 ||
          column == document.columns.length ||
          document.columns[column].kind != document.columns[column - 1].kind;
      canvas.drawLine(
        Offset(x, rowsTop),
        Offset(x, rowsBottom),
        sectionEdge ? boldPaint : lightPaint,
      );
    }

    // Rail frame numbers (global, 1-based) on even frames.
    if (drawTexts) {
      for (var row = 0; row < page.frameCount; row += 1) {
        final frameNumber = page.startFrame + row + 1;
        if (frameNumber.isOdd) {
          continue;
        }
        _text(
          canvas,
          '$frameNumber',
          Offset(
            gridLeft + 3,
            rowsTop + row * TimesheetDocumentLayout.rowHeight + 3,
          ),
          fontSize: 9,
          color: _gridBold,
        );
      }
    }

    // Cells.
    for (var column = 0; column < document.columns.length; column += 1) {
      final cells = document.columns[column].cells;
      final centerX =
          layout.columnLeft(column) + TimesheetDocumentLayout.columnWidth / 2;
      for (var row = 0; row < page.frameCount; row += 1) {
        final globalRow = page.startFrame + row;
        if (globalRow >= cells.length) {
          break;
        }
        final cell = cells[globalRow];
        if (cell.kind == TimesheetCellKind.empty) {
          continue;
        }
        final cellTop = rowsTop + row * TimesheetDocumentLayout.rowHeight;
        final cellCenterY = cellTop + TimesheetDocumentLayout.rowHeight / 2;
        switch (cell.kind) {
          case TimesheetCellKind.drawing:
            if (drawTexts) {
              _text(
                canvas,
                cell.label ?? '',
                Offset(centerX, cellTop + 3),
                fontSize: 10,
                color: _ink,
                centeredAtX: true,
              );
            }
          case TimesheetCellKind.held:
          case TimesheetCellKind.cameraSpan:
            canvas.drawLine(
              Offset(centerX, cellTop),
              Offset(centerX, cellTop + TimesheetDocumentLayout.rowHeight),
              Paint()
                ..color = _ink
                ..strokeWidth = cell.kind == TimesheetCellKind.cameraSpan
                    ? 1.6
                    : 1.0,
            );
          case TimesheetCellKind.mark:
            canvas.drawCircle(
              Offset(centerX, cellCenterY),
              4,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.1
                ..color = _ink,
            );
          case TimesheetCellKind.emptyRunStart:
            if (drawTexts) {
              _text(
                canvas,
                '×',
                Offset(centerX, cellTop + 2),
                fontSize: 11,
                color: _gridBold,
                centeredAtX: true,
              );
            }
          case TimesheetCellKind.cameraKey:
            canvas.drawCircle(
              Offset(centerX, cellCenterY),
              3.4,
              Paint()..color = _ink,
            );
          case TimesheetCellKind.empty:
            break;
        }
      }
    }
  }

  void _paintPlayhead(Canvas canvas) {
    final frame = playheadFrame;
    if (frame == null || frame < 0 || frame >= document.rowCount) {
      return;
    }
    final top = layout.frameRowTop(frame);
    canvas.drawRect(
      Rect.fromLTWH(
        layout.pageLeft + TimesheetDocumentLayout.pageMarginX,
        top,
        layout.columnLeft(document.columns.length) -
            layout.pageLeft -
            TimesheetDocumentLayout.pageMarginX,
        TimesheetDocumentLayout.rowHeight,
      ),
      Paint()..color = _playhead,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset topLeft, {
    required double fontSize,
    Color color = _ink,
    bool bold = false,
    bool centeredAtX = false,
    double? maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(
      canvas,
      centeredAtX ? topLeft - Offset(painter.width / 2, 0) : topLeft,
    );
  }

  @override
  bool shouldRepaint(covariant TimesheetDocumentPainter oldDelegate) {
    return !identical(oldDelegate.document, document) ||
        oldDelegate.layout.continuous != layout.continuous ||
        oldDelegate.viewport != viewport ||
        oldDelegate.playheadFrame != playheadFrame;
  }
}
