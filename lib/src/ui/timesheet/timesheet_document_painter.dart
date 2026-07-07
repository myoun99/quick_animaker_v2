import 'package:flutter/material.dart';

import '../../models/canvas_viewport.dart';
import '../../models/timesheet_document.dart';
import '../theme/app_theme.dart';

/// Geometry of the rendered sheet document in canvas (document) space,
/// modeled on the Japanese paper form (A-1/IG style): a B4-portrait page
/// whose body splits into two side-by-side halves of
/// [TimesheetDocument.halfFrameCount] rows; each half reads
/// frame-number gutter | ACTION block (animation layers) | S1·S2 |
/// CELL block | CAM. The gutter is bare numbers on paper (user direction —
/// no boxed rail, no grid), printed left of each half.
///
/// The continuous mode keeps the SAME paper width and header band as the
/// paged form (the paper size never changes with the view toggle — user
/// rule) and swaps only the body below: ONE half-structure strip with every
/// row in sequence (global frame numbers) growing downward, in page half
/// 0's exact geometry so ink coordinates stay stable across the toggle.
class TimesheetDocumentLayout {
  const TimesheetDocumentLayout({
    required this.document,
    this.continuous = false,
  });

  final TimesheetDocument document;
  final bool continuous;

  static const double rowHeight = 18;
  static const double actionColumnWidth = 24;
  static const double seColumnWidth = 20;
  static const double celColumnWidth = 24;
  static const double cameraColumnWidth = 36;

  /// Bare frame numbers print in this space LEFT of each half — no boxed
  /// rail inside the columns (removed by user direction).
  static const double frameNumberGutterWidth = 24;
  static const double groupRowHeight = 16;
  static const double letterRowHeight = 16;
  static const double headerBandHeight = 64;

  /// The Direction handwriting space under the header band (real-sheet
  /// reference ~140px), with a framed memo box at its top right. Printed on
  /// every page; page ink (S2) anchors on it.
  static const double memoBandHeight = 140;
  static const double memoBoxWidthFraction = 0.28;
  static const double memoBoxHeight = 56;
  static const double headerGap = 10;
  static const double pagePadding = 16;
  static const double halfGap = 24;
  static const double pageGap = 32;
  static const double documentMargin = 24;

  static double columnWidthFor(TimesheetColumnKind kind) {
    return switch (kind) {
      TimesheetColumnKind.action => actionColumnWidth,
      TimesheetColumnKind.se => seColumnWidth,
      TimesheetColumnKind.cel => celColumnWidth,
      TimesheetColumnKind.camera => cameraColumnWidth,
    };
  }

  double get columnsHeaderHeight => groupRowHeight + letterRowHeight;

  /// x of a column within its half (a plain prefix sum — frame numbers
  /// live in the gutter left of the half, not between columns).
  double columnLeftInHalf(int columnIndex) {
    var x = 0.0;
    for (var index = 0; index < columnIndex; index += 1) {
      x += columnWidthFor(document.columns[index].kind);
    }
    return x;
  }

  /// Width of a half's column area (the number gutter sits outside it).
  double get halfWidth {
    var width = 0.0;
    for (final column in document.columns) {
      width += columnWidthFor(column.kind);
    }
    return width;
  }

  /// One fixed paper width in BOTH modes — the view toggle never resizes
  /// the paper (or the header band that spans it).
  double get paperWidth =>
      pagePadding * 2 + (frameNumberGutterWidth + halfWidth) * 2 + halfGap;

  /// Rows in the given half of a page (the second half takes the odd
  /// remainder).
  int halfRowCount(int half) => half == 0
      ? document.halfFrameCount
      : document.pageFrameCount - document.halfFrameCount;

  int get _maxHalfRows =>
      halfRowCount(0) > halfRowCount(1) ? halfRowCount(0) : halfRowCount(1);

  double get _pagedBodyHeight => columnsHeaderHeight + _maxHalfRows * rowHeight;

  double get paperHeight => continuous
      ? pagePadding * 2 +
            headerBandHeight +
            memoBandHeight +
            headerGap +
            columnsHeaderHeight +
            document.rowCount * rowHeight
      : pagePadding * 2 +
            headerBandHeight +
            memoBandHeight +
            headerGap +
            _pagedBodyHeight;

  double get paperLeft => documentMargin;

  double pageTop(int pageIndex) => continuous
      ? documentMargin
      : documentMargin + pageIndex * (paperHeight + pageGap);

  /// The paper rect of a page (the whole strip in continuous mode).
  Rect pageRect(int pageIndex) {
    if (continuous) {
      return Rect.fromLTWH(paperLeft, documentMargin, paperWidth, paperHeight);
    }
    return Rect.fromLTWH(
      paperLeft,
      pageTop(pageIndex),
      paperWidth,
      paperHeight,
    );
  }

  /// Left edge of a half's column area (past its number gutter).
  double halfLeft(int pageIndex, int half) {
    if (continuous) {
      return paperLeft + pagePadding + frameNumberGutterWidth;
    }
    return paperLeft +
        pagePadding +
        frameNumberGutterWidth +
        half * (frameNumberGutterWidth + halfWidth + halfGap);
  }

  /// Top of a half's first row.
  double halfRowsTop(int pageIndex) =>
      pageTop(pageIndex) +
      pagePadding +
      headerBandHeight +
      memoBandHeight +
      headerGap +
      columnsHeaderHeight;

  /// The memo band rect of a page — directly under the header band.
  Rect memoBandRect(int pageIndex) {
    final page = pageRect(pageIndex);
    return Rect.fromLTWH(
      page.left + pagePadding,
      page.top + pagePadding + headerBandHeight,
      page.width - pagePadding * 2,
      memoBandHeight,
    );
  }

  /// Where a global frame lands: page, half and row within the half. The
  /// continuous strip is a single half per "page block".
  ({int page, int half, int row}) positionOfFrame(int frameIndex) {
    if (continuous) {
      return (page: 0, half: 0, row: frameIndex);
    }
    final page = frameIndex ~/ document.pageFrameCount;
    final local = frameIndex % document.pageFrameCount;
    final half = local < document.halfFrameCount ? 0 : 1;
    return (
      page: page,
      half: half,
      row: half == 0 ? local : local - document.halfFrameCount,
    );
  }

  /// Top edge of a global frame row.
  double frameRowTop(int frameIndex) {
    final position = positionOfFrame(frameIndex);
    return halfRowsTop(position.page) + position.row * rowHeight;
  }

  /// The data-driven cut-end line (the paper's horizontal strikethrough,
  /// S2-0): the bottom edge of the LAST playback frame row, spanning its
  /// half — not ink, same concept as the timeline's cut-end boundary.
  ({int page, int half, double y}) get cutEndLine {
    final lastFrame = document.playbackFrameCount - 1;
    final position = positionOfFrame(lastFrame);
    return (
      page: position.page,
      half: position.half,
      y: frameRowTop(lastFrame) + rowHeight,
    );
  }

  /// Logical size of the whole document.
  Size get documentSize {
    final pageCount = document.pages.length;
    final height = continuous
        ? documentMargin * 2 + paperHeight
        : documentMargin * 2 +
              pageCount * paperHeight +
              (pageCount - 1) * pageGap;
    return Size(documentMargin * 2 + paperWidth, height);
  }
}

/// Paints the sheet document — the paper form (header band, Direction memo
/// band, group/letter rows, second-heavy grid), cel numbers, holds, ○
/// marks, X cells, camera keys, the data-driven cut-end strikethrough and
/// the playhead row — under the panel viewport transform (the same
/// inside-the-picture transform the brush canvas uses, crisp at any zoom).
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

  static const Color _paper = Color(0xFFF6F4F0);
  static const Color _ink = Color(0xFF33322F);
  static const Color _gridLight = Color(0xFFCFC9BF);
  static const Color _gridMedium = Color(0xFFA9A296);
  static const Color _gridBold = Color(0xFF6E6759);
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

    if (layout.continuous) {
      _paintPaper(canvas, 0);
      _paintHeaderBand(canvas, 0, drawTexts: drawTexts);
      _paintMemoBand(canvas, 0);
      _paintHalf(
        canvas,
        pageIndex: 0,
        half: 0,
        startFrame: 0,
        rowCount: document.rowCount,
        drawTexts: drawTexts,
      );
    } else {
      for (final page in document.pages) {
        _paintPaper(canvas, page.index);
        _paintHeaderBand(canvas, page.index, drawTexts: drawTexts);
        _paintMemoBand(canvas, page.index);
        for (var half = 0; half < 2; half += 1) {
          final rowCount = layout.halfRowCount(half);
          if (rowCount <= 0) {
            continue;
          }
          _paintHalf(
            canvas,
            pageIndex: page.index,
            half: half,
            startFrame:
                page.startFrame + (half == 0 ? 0 : document.halfFrameCount),
            rowCount: rowCount,
            drawTexts: drawTexts,
          );
        }
      }
    }
    _paintCutEndLine(canvas);
    _paintPlayhead(canvas);

    canvas.restore();
  }

  void _paintPaper(Canvas canvas, int pageIndex) {
    final rect = layout.pageRect(pageIndex);
    canvas.drawRect(rect, Paint()..color = _paper);
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _gridBold,
    );
  }

  /// The header band: labeled boxes like the paper form —
  /// タイトル/話数 | CUT | TIME | NAME | SHEET.
  void _paintHeaderBand(
    Canvas canvas,
    int pageIndex, {
    required bool drawTexts,
  }) {
    final pageRect = layout.pageRect(pageIndex);
    final band = Rect.fromLTWH(
      pageRect.left + TimesheetDocumentLayout.pagePadding,
      pageRect.top + TimesheetDocumentLayout.pagePadding,
      pageRect.width - TimesheetDocumentLayout.pagePadding * 2,
      TimesheetDocumentLayout.headerBandHeight,
    );

    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _gridBold;
    canvas.drawRect(band, boxPaint);

    // Field boxes, widths as fractions of the band.
    final fractions = [0.36, 0.14, 0.14, 0.2, 0.16];
    final labels = ['TITLE / 話数', 'CUT', 'TIME', 'NAME', 'SHEET'];
    final sheetLabel = layout.continuous
        ? '1/1'
        : '${pageIndex + 1}/${document.pages.length}';
    final values = [
      document.episode.isEmpty
          ? document.title
          : '${document.title}  ${document.episode}',
      document.cutName,
      document.durationLabel,
      document.artist,
      sheetLabel,
    ];

    var x = band.left;
    for (var box = 0; box < fractions.length; box += 1) {
      final width = band.width * fractions[box];
      final rect = Rect.fromLTWH(x, band.top, width, band.height);
      canvas.drawRect(rect, boxPaint);
      if (drawTexts) {
        _text(
          canvas,
          labels[box],
          Offset(rect.left + 6, rect.top + 4),
          fontSize: 8,
          color: _gridMedium,
        );
        _text(
          canvas,
          values[box],
          Offset(rect.left + 8, rect.top + 26),
          fontSize: 14,
          bold: true,
          maxWidth: width - 16,
        );
      }
      x += width;
    }
  }

  /// The Direction memo band under the header: open handwriting space with
  /// a framed memo box at its top right — printed on every page.
  void _paintMemoBand(Canvas canvas, int pageIndex) {
    final band = layout.memoBandRect(pageIndex);
    canvas.drawRect(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = _gridBold,
    );
    final boxWidth = band.width * TimesheetDocumentLayout.memoBoxWidthFraction;
    canvas.drawRect(
      Rect.fromLTWH(
        band.right - boxWidth,
        band.top,
        boxWidth,
        TimesheetDocumentLayout.memoBoxHeight,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = _gridMedium,
    );
  }

  /// The cut-end strikethrough at the bottom edge of the last playback
  /// frame row — DATA rendering (S2-0), the same visual language as the
  /// timeline's cut-end boundary, never ink.
  void _paintCutEndLine(Canvas canvas) {
    if (document.playbackFrameCount < 1 ||
        document.playbackFrameCount > document.rowCount) {
      return;
    }
    final line = layout.cutEndLine;
    final left = layout.halfLeft(line.page, line.half);
    canvas.drawLine(
      Offset(left, line.y),
      Offset(left + layout.halfWidth, line.y),
      Paint()
        ..color = AppColors.danger
        ..strokeWidth = 2.4,
    );
  }

  void _paintHalf(
    Canvas canvas, {
    required int pageIndex,
    required int half,
    required int startFrame,
    required int rowCount,
    required bool drawTexts,
  }) {
    final left = layout.halfLeft(pageIndex, half);
    final rowsTop = layout.halfRowsTop(pageIndex);
    final rowsBottom = rowsTop + rowCount * TimesheetDocumentLayout.rowHeight;
    final right = left + layout.halfWidth;
    final columnsTop = rowsTop - layout.columnsHeaderHeight;
    final lettersTop = rowsTop - TimesheetDocumentLayout.letterRowHeight;

    final lightPaint = Paint()
      ..color = _gridLight
      ..strokeWidth = 0.6;
    final mediumPaint = Paint()
      ..color = _gridMedium
      ..strokeWidth = 1.0;
    final boldPaint = Paint()
      ..color = _gridBold
      ..strokeWidth = 1.6;

    // Group titles + letter row.
    if (drawTexts) {
      _paintGroupTitles(canvas, left, columnsTop);
      for (var column = 0; column < document.columns.length; column += 1) {
        // Unbacked slots print nothing — no placeholder letters.
        if (document.columns[column].label.isEmpty) {
          continue;
        }
        final columnLeft = left + layout.columnLeftInHalf(column);
        final columnWidth = TimesheetDocumentLayout.columnWidthFor(
          document.columns[column].kind,
        );
        _text(
          canvas,
          document.columns[column].label,
          Offset(columnLeft + columnWidth / 2, lettersTop + 2),
          fontSize: 9,
          color: _ink,
          centeredAtX: true,
          maxWidth: columnWidth - 2,
        );
      }
    }
    canvas.drawLine(
      Offset(left, columnsTop),
      Offset(right, columnsTop),
      mediumPaint,
    );
    canvas.drawLine(
      Offset(left, lettersTop),
      Offset(right, lettersTop),
      lightPaint,
    );

    // Row lines: light per frame, medium every 6 frames, bold on second
    // boundaries with the second index in the number gutter.
    final numbersRight = left - 4;
    for (var row = 0; row <= rowCount; row += 1) {
      final frame = startFrame + row;
      final y = rowsTop + row * TimesheetDocumentLayout.rowHeight;
      final Paint paint;
      if (frame % document.fps == 0 || row == rowCount) {
        paint = boldPaint;
      } else if (frame % 6 == 0) {
        paint = mediumPaint;
      } else {
        paint = lightPaint;
      }
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);

      if (drawTexts && row < rowCount && frame % document.fps == 0) {
        // Second index printed just under each second boundary.
        final second = frame ~/ document.fps + 1;
        _text(
          canvas,
          '$second',
          Offset(numbersRight, y + 2),
          fontSize: 8,
          bold: true,
          color: _gridBold,
          rightAlignedAtX: true,
        );
      }
    }

    // Vertical lines: half edges + column separators (bold at section
    // changes). The number gutter draws NO lines — bare numbers on paper.
    canvas.drawLine(
      Offset(left, columnsTop),
      Offset(left, rowsBottom),
      boldPaint,
    );
    canvas.drawLine(
      Offset(right, columnsTop),
      Offset(right, rowsBottom),
      boldPaint,
    );
    for (var column = 1; column < document.columns.length; column += 1) {
      final x = left + layout.columnLeftInHalf(column);
      final sectionEdge =
          document.columns[column].kind != document.columns[column - 1].kind;
      canvas.drawLine(
        Offset(x, sectionEdge ? columnsTop : lettersTop),
        Offset(x, rowsBottom),
        sectionEdge ? boldPaint : lightPaint,
      );
    }

    // Gutter frame numbers on even frames, bare on the paper left of the
    // half — page-local on paper, global in the continuous strip.
    if (drawTexts) {
      for (var row = 0; row < rowCount; row += 1) {
        final frame = startFrame + row;
        final printed = layout.continuous
            ? frame + 1
            : frame % document.pageFrameCount + 1;
        if (printed.isOdd) {
          continue;
        }
        _text(
          canvas,
          '$printed',
          Offset(
            numbersRight,
            rowsTop + row * TimesheetDocumentLayout.rowHeight + 4,
          ),
          fontSize: 8,
          color: _gridMedium,
          rightAlignedAtX: true,
        );
      }
    }

    // Cells (ACTION columns carry the animation layers' exposures).
    for (var column = 0; column < document.columns.length; column += 1) {
      final spec = document.columns[column];
      final centerX =
          left +
          layout.columnLeftInHalf(column) +
          TimesheetDocumentLayout.columnWidthFor(spec.kind) / 2;
      for (var row = 0; row < rowCount; row += 1) {
        final frame = startFrame + row;
        if (frame >= spec.cells.length) {
          break;
        }
        final cell = spec.cells[frame];
        if (cell.kind == TimesheetCellKind.empty) {
          continue;
        }
        final cellTop = rowsTop + row * TimesheetDocumentLayout.rowHeight;
        final cellBottom = cellTop + TimesheetDocumentLayout.rowHeight;
        final cellCenterY = cellTop + TimesheetDocumentLayout.rowHeight / 2;
        // SE dialogue runs vertically beside its duration line; instruction
        // writing runs beside the arrow shaft (paper notation).
        final seColumn = spec.kind == TimesheetColumnKind.se;
        final holdLineX = seColumn ? centerX + 5 : centerX;
        final shaftX = centerX + 8;
        switch (cell.kind) {
          case TimesheetCellKind.drawing:
            if (drawTexts) {
              if (seColumn) {
                final rowsHere = (cell.spanLength ?? 1).clamp(
                  1,
                  rowCount - row,
                );
                _verticalText(
                  canvas,
                  cell.label ?? '',
                  topCenter: Offset(centerX - 3, cellTop + 2),
                  fontSize: 9,
                  maxHeight: rowsHere * TimesheetDocumentLayout.rowHeight - 4,
                );
              } else {
                _text(
                  canvas,
                  cell.label ?? '',
                  Offset(centerX, cellTop + 3),
                  fontSize: 10,
                  color: _ink,
                  centeredAtX: true,
                );
              }
            }
          case TimesheetCellKind.held:
          case TimesheetCellKind.cameraSpan:
            canvas.drawLine(
              Offset(holdLineX, cellTop),
              Offset(holdLineX, cellBottom),
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
                color: _gridMedium,
                centeredAtX: true,
              );
            }
          case TimesheetCellKind.cameraKey:
            canvas.drawCircle(
              Offset(centerX, cellCenterY),
              3.4,
              Paint()..color = _ink,
            );
          case TimesheetCellKind.instructionStart:
            final shaft = Paint()
              ..color = _ink
              ..strokeWidth = 1.4;
            final singleRow = (cell.spanLength ?? 1) <= 1;
            // Shaft leaves from the row middle; single-frame instructions
            // get the arrowhead right here.
            canvas.drawLine(
              Offset(shaftX, cellCenterY),
              Offset(shaftX, cellBottom),
              shaft,
            );
            if (singleRow) {
              _paintArrowhead(canvas, Offset(shaftX, cellBottom), shaft);
            }
            if (drawTexts) {
              final rowsHere = (cell.spanLength ?? 1).clamp(1, rowCount - row);
              _verticalText(
                canvas,
                cell.label ?? '',
                topCenter: Offset(centerX - 6, cellTop + 2),
                fontSize: 9,
                maxHeight: rowsHere * TimesheetDocumentLayout.rowHeight - 4,
              );
              if (cell.valueA != null && cell.valueA!.isNotEmpty) {
                _text(
                  canvas,
                  cell.valueA!,
                  Offset(shaftX + 2, cellTop + 1),
                  fontSize: 7,
                  color: _ink,
                );
              }
              if (singleRow && cell.valueB != null && cell.valueB!.isNotEmpty) {
                _text(
                  canvas,
                  cell.valueB!,
                  Offset(shaftX + 2, cellBottom - 9),
                  fontSize: 7,
                  color: _ink,
                );
              }
            }
          case TimesheetCellKind.instructionSpan:
            canvas.drawLine(
              Offset(shaftX, cellTop),
              Offset(shaftX, cellBottom),
              Paint()
                ..color = _ink
                ..strokeWidth = 1.4,
            );
          case TimesheetCellKind.instructionEnd:
            final shaft = Paint()
              ..color = _ink
              ..strokeWidth = 1.4;
            canvas.drawLine(
              Offset(shaftX, cellTop),
              Offset(shaftX, cellBottom - 1),
              shaft,
            );
            _paintArrowhead(canvas, Offset(shaftX, cellBottom - 1), shaft);
            if (drawTexts && cell.valueB != null && cell.valueB!.isNotEmpty) {
              _text(
                canvas,
                cell.valueB!,
                Offset(shaftX + 2, cellBottom - 9),
                fontSize: 7,
                color: _ink,
              );
            }
          case TimesheetCellKind.empty:
            break;
        }
      }
    }
  }

  /// A small downward arrowhead closing an instruction span.
  void _paintArrowhead(Canvas canvas, Offset tip, Paint paint) {
    canvas.drawLine(tip, tip + const Offset(-3.2, -4.5), paint);
    canvas.drawLine(tip, tip + const Offset(3.2, -4.5), paint);
  }

  void _paintGroupTitles(Canvas canvas, double halfLeft, double groupTop) {
    // Contiguous kind runs become group headers (ACTION / S / CELL / CAM).
    var runStart = 0;
    while (runStart < document.columns.length) {
      final kind = document.columns[runStart].kind;
      var runEnd = runStart;
      while (runEnd + 1 < document.columns.length &&
          document.columns[runEnd + 1].kind == kind) {
        runEnd += 1;
      }
      final leftX = halfLeft + layout.columnLeftInHalf(runStart);
      final rightX =
          halfLeft +
          layout.columnLeftInHalf(runEnd) +
          TimesheetDocumentLayout.columnWidthFor(kind);
      final title = switch (kind) {
        TimesheetColumnKind.action => 'ACTION',
        TimesheetColumnKind.se => 'S',
        TimesheetColumnKind.cel => 'CELL',
        TimesheetColumnKind.camera => 'CAM',
      };
      _text(
        canvas,
        title,
        Offset((leftX + rightX) / 2, groupTop + 2),
        fontSize: 9,
        bold: true,
        color: _ink,
        centeredAtX: true,
      );
      runStart = runEnd + 1;
    }
  }

  void _paintPlayhead(Canvas canvas) {
    final frame = playheadFrame;
    if (frame == null || frame < 0 || frame >= document.rowCount) {
      return;
    }
    final position = layout.positionOfFrame(frame);
    final left = layout.halfLeft(position.page, position.half);
    canvas.drawRect(
      Rect.fromLTWH(
        left,
        layout.frameRowTop(frame),
        layout.halfWidth,
        TimesheetDocumentLayout.rowHeight,
      ),
      Paint()..color = _playhead,
    );
  }

  /// Vertical writing, Japanese-sheet style: upright glyphs stacked top to
  /// bottom (no rotation), clamped to [maxHeight] with a closing ellipsis.
  void _verticalText(
    Canvas canvas,
    String text, {
    required Offset topCenter,
    required double fontSize,
    required double maxHeight,
    Color color = _ink,
  }) {
    var y = topCenter.dy;
    final bottom = topCenter.dy + maxHeight;
    final glyphs = text.characters.toList(growable: false);
    for (var index = 0; index < glyphs.length; index += 1) {
      final painter = TextPainter(
        text: TextSpan(
          text: glyphs[index],
          style: TextStyle(color: color, fontSize: fontSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final lastThatFits = y + painter.height > bottom - fontSize;
      if (lastThatFits && index < glyphs.length - 1) {
        final ellipsis = TextPainter(
          text: TextSpan(
            text: '…',
            style: TextStyle(color: color, fontSize: fontSize),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        ellipsis.paint(canvas, Offset(topCenter.dx - ellipsis.width / 2, y));
        return;
      }
      if (y + painter.height > bottom) {
        return;
      }
      painter.paint(canvas, Offset(topCenter.dx - painter.width / 2, y));
      y += painter.height - 2;
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor, {
    required double fontSize,
    Color color = _ink,
    bool bold = false,
    bool centeredAtX = false,
    bool rightAlignedAtX = false,
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
    final offset = centeredAtX
        ? anchor - Offset(painter.width / 2, 0)
        : rightAlignedAtX
        ? anchor - Offset(painter.width, 0)
        : anchor;
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant TimesheetDocumentPainter oldDelegate) {
    return !identical(oldDelegate.document, document) ||
        oldDelegate.layout.continuous != layout.continuous ||
        oldDelegate.viewport != viewport ||
        oldDelegate.playheadFrame != playheadFrame;
  }
}
