import 'package:flutter/material.dart';

import '../../models/camera_instruction.dart';
import '../../models/canvas_viewport.dart';
import '../../models/timesheet_document.dart';
import '../../models/timesheet_info.dart';
import '../text/dialogue_fit_layout.dart';
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

  /// The CAM group's FIXED total width — the B4 paper must never widen
  /// when a cut carries more instruction rows (user rule): extra CAM
  /// columns split this allotment into narrower cells instead.
  static const double cameraGroupWidth = cameraColumnWidth * 2;

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

  int get _cameraColumnCount {
    var count = 0;
    for (final column in document.columns) {
      if (column.kind == TimesheetColumnKind.camera) {
        count += 1;
      }
    }
    return count;
  }

  /// Per-column width. Instance-level because CAM cells share the fixed
  /// [cameraGroupWidth]: past the base two slots each CAM column narrows so
  /// the paper width stays put.
  double columnWidthFor(TimesheetColumnKind kind) {
    if (kind == TimesheetColumnKind.camera && _cameraColumnCount > 2) {
      return cameraGroupWidth / _cameraColumnCount;
    }
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

  /// Width fractions of the header boxes when all print; hiding boxes
  /// renormalizes the rest over the band.
  static const Map<TimesheetHeaderField, double> _headerFieldFractions = {
    TimesheetHeaderField.title: 0.26,
    TimesheetHeaderField.episode: 0.08,
    TimesheetHeaderField.scene: 0.10,
    TimesheetHeaderField.cut: 0.10,
    TimesheetHeaderField.time: 0.12,
    TimesheetHeaderField.name: 0.20,
    TimesheetHeaderField.sheet: 0.14,
  };

  /// The header band rect of a page — its LEFT edge sits on the grid's
  /// left bold line (the paper form's header table left-aligns with the
  /// ACTION block; the number gutter stays outside both — user fix), its
  /// right edge on half 1's right bold line.
  Rect headerBandRect(int pageIndex) {
    final page = pageRect(pageIndex);
    final left = page.left + pagePadding + frameNumberGutterWidth;
    return Rect.fromLTWH(
      left,
      page.top + pagePadding,
      page.right - pagePadding - left,
      headerBandHeight,
    );
  }

  /// The visible header boxes of a page, in printing order — shared by the
  /// painter and the tap-to-edit layer.
  List<({TimesheetHeaderField field, Rect rect})> headerFieldBoxes(
    int pageIndex,
  ) {
    final fields = document.visibleHeaderFields;
    if (fields.isEmpty) {
      return const [];
    }
    final band = headerBandRect(pageIndex);
    var total = 0.0;
    for (final field in fields) {
      total += _headerFieldFractions[field]!;
    }
    final boxes = <({TimesheetHeaderField field, Rect rect})>[];
    var x = band.left;
    for (var index = 0; index < fields.length; index += 1) {
      // The last box closes exactly on the band edge (no rounding drift).
      final right = index == fields.length - 1
          ? band.right
          : x + band.width * (_headerFieldFractions[fields[index]]! / total);
      boxes.add((
        field: fields[index],
        rect: Rect.fromLTRB(x, band.top, right, band.bottom),
      ));
      x = right;
    }
    return boxes;
  }

  /// The memo band rect of a page — directly under the header band, same
  /// grid-aligned edges.
  Rect memoBandRect(int pageIndex) {
    final band = headerBandRect(pageIndex);
    return Rect.fromLTWH(band.left, band.bottom, band.width, memoBandHeight);
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
      _paintMemoBand(canvas, 0, drawTexts: drawTexts);
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
        _paintMemoBand(canvas, page.index, drawTexts: drawTexts);
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
  /// TITLE | # | SCENE | CUT | TIME | NAME | SHEET, minus hidden boxes.
  void _paintHeaderBand(
    Canvas canvas,
    int pageIndex, {
    required bool drawTexts,
  }) {
    final band = layout.headerBandRect(pageIndex);
    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _gridBold;
    canvas.drawRect(band, boxPaint);

    for (final box in layout.headerFieldBoxes(pageIndex)) {
      canvas.drawRect(box.rect, boxPaint);
      if (!drawTexts) {
        continue;
      }
      _text(
        canvas,
        headerFieldLabel(box.field),
        Offset(box.rect.left + 6, box.rect.top + 4),
        fontSize: 8,
        color: _gridMedium,
      );
      _text(
        canvas,
        _headerFieldValue(box.field, pageIndex),
        Offset(box.rect.left + 8, box.rect.top + 26),
        fontSize: 14,
        bold: true,
        maxWidth: box.rect.width - 16,
      );
    }
  }

  /// The printed box label — '#' is the paper form's episode (話数) box.
  static String headerFieldLabel(TimesheetHeaderField field) {
    return switch (field) {
      TimesheetHeaderField.title => 'TITLE',
      TimesheetHeaderField.episode => '#',
      TimesheetHeaderField.scene => 'SCENE',
      TimesheetHeaderField.cut => 'CUT',
      TimesheetHeaderField.time => 'TIME',
      TimesheetHeaderField.name => 'NAME',
      TimesheetHeaderField.sheet => 'SHEET',
    };
  }

  String _headerFieldValue(TimesheetHeaderField field, int pageIndex) {
    return switch (field) {
      TimesheetHeaderField.title => document.title,
      TimesheetHeaderField.episode => document.episode,
      TimesheetHeaderField.scene => document.scene,
      TimesheetHeaderField.cut => document.cutName,
      TimesheetHeaderField.time => document.durationLabel,
      TimesheetHeaderField.name => document.artist,
      TimesheetHeaderField.sheet =>
        layout.continuous ? '1/1' : '${pageIndex + 1}/${document.pages.length}',
    };
  }

  /// The Direction memo band under the header: open handwriting space with
  /// a framed memo box at its top right — printed on every page. The cut's
  /// Direction memo (cut note) types into its top left.
  void _paintMemoBand(Canvas canvas, int pageIndex, {required bool drawTexts}) {
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
    if (!drawTexts) {
      return;
    }
    final textMaxWidth = band.width - boxWidth - 20;
    var y = band.top + 6;
    if (document.memoText.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(
          text: document.memoText,
          style: const TextStyle(color: _ink, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 8,
        ellipsis: '…',
      )..layout(maxWidth: textMaxWidth);
      painter.paint(canvas, Offset(band.left + 8, y));
      y += painter.height + 4;
    }
    // The camera-instruction shorthand lines ('C⋈D O.L(カットO.L)' …) stack
    // under the cut note; whatever exceeds the band stays unprinted (the
    // band is fixed paper space).
    for (final line in document.memoInstructionLines) {
      final painter = TextPainter(
        text: TextSpan(
          text: line,
          style: const TextStyle(color: _ink, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: textMaxWidth);
      if (y + painter.height > band.bottom - 4) {
        break;
      }
      painter.paint(canvas, Offset(band.left + 8, y));
      y += painter.height + 2;
    }
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
        final columnWidth = layout.columnWidthFor(
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
    // boundaries.
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
    // half — page-local on paper, global in the continuous strip. On each
    // second's LAST frame row (24, 48, …) the second index prints BOLD in
    // place of the frame number — the paper convention (A-1 form).
    if (drawTexts) {
      for (var row = 0; row < rowCount; row += 1) {
        final frame = startFrame + row;
        final printed = layout.continuous
            ? frame + 1
            : frame % document.pageFrameCount + 1;
        final rowTop = rowsTop + row * TimesheetDocumentLayout.rowHeight;
        if (printed % document.fps == 0) {
          _text(
            canvas,
            '${printed ~/ document.fps}',
            Offset(numbersRight, rowTop + 3),
            fontSize: 10,
            bold: true,
            color: _gridBold,
            rightAlignedAtX: true,
          );
          continue;
        }
        if (printed.isOdd) {
          continue;
        }
        _text(
          canvas,
          '$printed',
          Offset(numbersRight, rowTop + 4),
          fontSize: 8,
          color: _gridMedium,
          rightAlignedAtX: true,
        );
      }
    }

    // Cells (ACTION columns carry the animation layers' exposures).
    for (var column = 0; column < document.columns.length; column += 1) {
      final spec = document.columns[column];
      final columnLeft = left + layout.columnLeftInHalf(column);
      final columnWidth = layout.columnWidthFor(spec.kind);
      final centerX = columnLeft + columnWidth / 2;
      for (var row = 0; row < rowCount; row += 1) {
        final frame = startFrame + row;
        if (frame >= spec.cells.length) {
          break;
        }
        final cell = spec.cells[frame];
        final seColumn = spec.kind == TimesheetColumnKind.se;
        final cellTop = rowsTop + row * TimesheetDocumentLayout.rowHeight;
        final cellBottom = cellTop + TimesheetDocumentLayout.rowHeight;
        final cellCenterY = cellTop + TimesheetDocumentLayout.rowHeight / 2;
        if (cell.kind == TimesheetCellKind.empty) {
          // SE columns mark their empty stretches the print-sheet way: a
          // dotted center guide, washed light gray while the toggle is on.
          if (seColumn && frame < document.playbackFrameCount) {
            _paintSeEmptyRow(
              canvas,
              columnLeft: columnLeft,
              columnWidth: columnWidth,
              centerX: centerX,
              cellTop: cellTop,
            );
          }
          continue;
        }
        switch (cell.kind) {
          case TimesheetCellKind.drawing:
            if (drawTexts) {
              if (seColumn) {
                _paintSeEntryStart(
                  canvas,
                  cell: cell,
                  row: row,
                  rowCount: rowCount,
                  columnLeft: columnLeft,
                  columnWidth: columnWidth,
                  centerX: centerX,
                  cellTop: cellTop,
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
            if (seColumn) {
              // Toei SE notation: no hold line down the dialogue; the
              // block's END closes with a short red underline instead.
              if ((cell.spanOffset ?? 0) == (cell.spanLength ?? 1) - 1) {
                _paintSeEndUnderline(
                  canvas,
                  centerX: centerX,
                  columnWidth: columnWidth,
                  y: cellBottom - 1,
                );
              }
              break;
            }
            // ACTION hold bar: off by default; with a threshold N it runs
            // from the (N+1)th comma of N+ holds only (industry N=3).
            final threshold = document.exposureBarThreshold;
            if (threshold != null && (cell.spanOffset ?? 0) >= threshold) {
              canvas.drawLine(
                Offset(centerX, cellTop),
                Offset(centerX, cellBottom),
                Paint()
                  ..color = _ink
                  ..strokeWidth = 1.0,
              );
            }
          case TimesheetCellKind.cameraSpan:
            canvas.drawLine(
              Offset(centerX, cellTop),
              Offset(centerX, cellBottom),
              Paint()
                ..color = _ink
                ..strokeWidth = 1.6,
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
          case TimesheetCellKind.instructionSpan:
          case TimesheetCellKind.instructionEnd:
            // One shared per-row renderer — the printed sheet mirrors the
            // X-sheet column verbatim: the mark owns the whole cell width,
            // A/B center in their endpoint cells (frame-name style) and
            // the writing centers on the span's middle row.
            _paintInstructionRow(
              canvas,
              cell: cell,
              columnLeft: columnLeft,
              columnWidth: columnWidth,
              centerX: centerX,
              cellTop: cellTop,
              drawTexts: drawTexts,
            );
          case TimesheetCellKind.empty:
            break;
        }
      }
    }
  }

  /// One row of an instruction span, in the X-sheet's exact visual
  /// language (R4): the bar mark is ONE unadorned continuous line between
  /// the endpoint rows' centers — no end ticks, never broken for text —
  /// and FI/FO/O.L marks are light-gray filled wedges owning the full
  /// column width; the A/B names center in the start/end cells like frame
  /// names and the writing centers on the SPAN's true center, drawn over
  /// the mark.
  void _paintInstructionRow(
    Canvas canvas, {
    required TimesheetCell cell,
    required double columnLeft,
    required double columnWidth,
    required double centerX,
    required double cellTop,
    required bool drawTexts,
  }) {
    const rowHeight = TimesheetDocumentLayout.rowHeight;
    final cellBottom = cellTop + rowHeight;
    final cellCenterY = cellTop + rowHeight / 2;
    final spanLength = cell.spanLength ?? 1;
    final offset = cell.spanOffset ?? 0;
    final isFirst = offset == 0;
    final isLast = offset == spanLength - 1;

    if ((cell.markType ?? CameraInstructionMarkType.bar) ==
        CameraInstructionMarkType.bar) {
      // Single-row spans carry writing only, exactly like the row overlay.
      if (spanLength > 1) {
        canvas.drawLine(
          Offset(centerX, isFirst ? cellCenterY : cellTop),
          Offset(centerX, isLast ? cellCenterY : cellBottom),
          Paint()
            ..color = _ink
            ..strokeWidth = 1.4,
        );
      }
    } else {
      _paintInstructionMarkSlice(
        canvas,
        cell: cell,
        centerX: centerX,
        halfWidth: columnWidth / 2 - 1,
        cellTop: cellTop,
      );
    }

    if (!drawTexts) {
      return;
    }
    if (isFirst && (cell.valueA ?? '').isNotEmpty) {
      _text(
        canvas,
        cell.valueA!,
        Offset(centerX, cellTop + 3),
        fontSize: 10,
        color: _ink,
        centeredAtX: true,
        maxWidth: columnWidth - 2,
      );
    }
    if (isLast && !isFirst && (cell.valueB ?? '').isNotEmpty) {
      _text(
        canvas,
        cell.valueB!,
        Offset(centerX, cellTop + 3),
        fontSize: 10,
        color: _ink,
        centeredAtX: true,
        maxWidth: columnWidth - 2,
      );
    }
    if (isFirst && isLast && (cell.valueB ?? '').isNotEmpty) {
      // Single-row span: B shares the row under A.
      _text(
        canvas,
        cell.valueB!,
        Offset(centerX, cellBottom - 9),
        fontSize: 7,
        color: _ink,
        centeredAtX: true,
        maxWidth: columnWidth - 2,
      );
    }
    if (offset == (spanLength - 1) ~/ 2 && (cell.label ?? '').isNotEmpty) {
      // The writing sits on the SPAN's true center (derived span-globally
      // like the mark geometry), overlaid on the line/wedge — never
      // breaking them (R4 rule).
      final spanTop = cellTop - offset * rowHeight;
      _centeredVerticalText(
        canvas,
        cell.label!,
        center: Offset(centerX, spanTop + spanLength * rowHeight / 2),
        fontSize: 9,
      );
    }
  }

  /// One row's slice of an instruction span's FI/FO wedge or O.L bowtie:
  /// the mark geometry derives span-globally from the cell's
  /// spanOffset/spanLength and clips to this row, so spans crossing page
  /// halves paint seamlessly (each half paints only its own rows). The
  /// mark owns the column's full width ([halfWidth] from the caller),
  /// exactly like the X-sheet overlay.
  void _paintInstructionMarkSlice(
    Canvas canvas, {
    required TimesheetCell cell,
    required double centerX,
    required double halfWidth,
    required double cellTop,
  }) {
    const rowHeight = TimesheetDocumentLayout.rowHeight;
    final shaftX = centerX;
    final spanTop = cellTop - (cell.spanOffset ?? 0) * rowHeight;
    final spanBottom = spanTop + (cell.spanLength ?? 1) * rowHeight;
    final mid = (spanTop + spanBottom) / 2;
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        shaftX - halfWidth - 1,
        cellTop,
        (halfWidth + 1) * 2,
        rowHeight,
      ),
    );
    // R4: dedicated marks are plain LIGHT-GRAY FILLS laid under the grid
    // and the writing — no hatching, no outline (user sketch).
    final fill = Paint()..color = _ink.withValues(alpha: 0.15);
    switch (cell.markType ?? CameraInstructionMarkType.bar) {
      case CameraInstructionMarkType.ol:
        canvas.drawPath(
          Path()..addPolygon([
            Offset(shaftX - halfWidth, spanTop),
            Offset(shaftX + halfWidth, spanTop),
            Offset(shaftX, mid),
          ], true),
          fill,
        );
        canvas.drawPath(
          Path()..addPolygon([
            Offset(shaftX - halfWidth, spanBottom),
            Offset(shaftX + halfWidth, spanBottom),
            Offset(shaftX, mid),
          ], true),
          fill,
        );
      case CameraInstructionMarkType.fi:
      case CameraInstructionMarkType.fo:
        // The fade wedge follows the light: FI opens narrow → wide (the
        // picture grows in), FO wide → narrow (R4 orientation fix).
        final fadeIn = cell.markType == CameraInstructionMarkType.fi;
        final wideY = fadeIn ? spanBottom - 1 : spanTop + 1;
        final pointY = fadeIn ? spanTop + 1 : spanBottom - 1;
        canvas.drawPath(
          Path()..addPolygon([
            Offset(shaftX - halfWidth, wideY),
            Offset(shaftX, pointY),
            Offset(shaftX + halfWidth, wideY),
          ], true),
          fill,
        );
      case CameraInstructionMarkType.bar:
        // Dispatched to the straight-line path before reaching here.
        break;
    }
    canvas.restore();
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
          layout.columnWidthFor(kind);
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

  /// An SE entry's start cell, the real Toei sheet way (R4, user-approved
  /// mockup v3): a compact INVERTED name box hugging the block's start
  /// boundary (ink fill, paper-light writing), the dialogue distributed
  /// vertically over the REST of the span — no duration bar. Single-row
  /// entries close with the red end underline right here; longer ones
  /// close from their last held row.
  void _paintSeEntryStart(
    Canvas canvas, {
    required TimesheetCell cell,
    required int row,
    required int rowCount,
    required double columnLeft,
    required double columnWidth,
    required double centerX,
    required double cellTop,
  }) {
    const rowHeight = TimesheetDocumentLayout.rowHeight;
    const nameBoxHeight = 12.0;
    final spanLength = cell.spanLength ?? 1;
    final rowsHere = spanLength.clamp(1, rowCount - row);
    final spanBottom = cellTop + rowsHere * rowHeight;
    final seName = cell.seName ?? '';

    var dialogueTop = cellTop + 2;
    if (seName.isNotEmpty) {
      canvas.drawRect(
        Rect.fromLTWH(columnLeft + 1, cellTop, columnWidth - 2, nameBoxHeight),
        Paint()..color = _ink,
      );
      _text(
        canvas,
        seName,
        Offset(centerX, cellTop + 2),
        fontSize: 7,
        bold: true,
        color: _paper,
        centeredAtX: true,
        maxWidth: columnWidth - 4,
      );
      dialogueTop = cellTop + nameBoxHeight + 2;
    }

    final dialogueExtent = spanBottom - 2 - dialogueTop;
    if (dialogueExtent > 4 && (cell.label ?? '').isNotEmpty) {
      _fitVerticalText(
        canvas,
        cell.label!,
        topCenter: Offset(centerX, dialogueTop),
        fontSize: 9,
        extent: dialogueExtent,
      );
    }

    if (spanLength == 1) {
      _paintSeEndUnderline(
        canvas,
        centerX: centerX,
        columnWidth: columnWidth,
        y: spanBottom - 1,
      );
    }
  }

  /// The short red underline closing an SE block (Toei notation).
  void _paintSeEndUnderline(
    Canvas canvas, {
    required double centerX,
    required double columnWidth,
    required double y,
  }) {
    final halfWidth = columnWidth * 0.3;
    canvas.drawLine(
      Offset(centerX - halfWidth, y),
      Offset(centerX + halfWidth, y),
      Paint()
        ..color = AppColors.danger
        ..strokeWidth = 2,
    );
  }

  /// An SE column's empty row: the light-gray "no SE here" wash (project
  /// toggle) under a dotted center guide — the print-sheet convention; the
  /// frame grid keeps printing through both.
  void _paintSeEmptyRow(
    Canvas canvas, {
    required double columnLeft,
    required double columnWidth,
    required double centerX,
    required double cellTop,
  }) {
    const rowHeight = TimesheetDocumentLayout.rowHeight;
    if (document.seEmptyFill) {
      canvas.drawRect(
        Rect.fromLTWH(columnLeft, cellTop, columnWidth, rowHeight),
        Paint()..color = _ink.withValues(alpha: 0.05),
      );
    }
    final dot = Paint()
      ..color = _gridMedium
      ..strokeWidth = 1.0;
    for (var y = cellTop + 2.0; y < cellTop + rowHeight - 1; y += 5.0) {
      canvas.drawLine(Offset(centerX, y), Offset(centerX, y + 2.0), dot);
    }
  }

  /// An upright glyph stack centered on [center] (the instruction writing
  /// on its span's middle row) — spills over neighbouring rows freely,
  /// like handwriting on the paper form and the X-sheet overlay.
  void _centeredVerticalText(
    Canvas canvas,
    String text, {
    required Offset center,
    required double fontSize,
    Color color = _ink,
  }) {
    final glyphs = text.characters.toList(growable: false);
    if (glyphs.isEmpty) {
      return;
    }
    final painters = [
      for (final glyph in glyphs)
        TextPainter(
          text: TextSpan(
            text: glyph,
            style: TextStyle(color: color, fontSize: fontSize),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    var totalHeight = -2.0 * (painters.length - 1);
    for (final painter in painters) {
      totalHeight += painter.height;
    }
    var y = center.dy - totalHeight / 2;
    for (final painter in painters) {
      painter.paint(canvas, Offset(center.dx - painter.width / 2, y));
      y += painter.height - 2;
    }
  }

  /// SE dialogue distributed evenly over the covered rows — the sheet's
  /// "fit" rule, sharing [dialogueGlyphCenters] with the timeline overlay
  /// so screen and print place glyphs identically. Never truncates: the
  /// dialogue owns its whole block, exactly like the paper column.
  void _fitVerticalText(
    Canvas canvas,
    String text, {
    required Offset topCenter,
    required double fontSize,
    required double extent,
    Color color = _ink,
  }) {
    final glyphs = text.characters.toList(growable: false);
    final centers = dialogueGlyphCenters(
      glyphCount: glyphs.length,
      mainExtent: extent,
    );
    for (var index = 0; index < glyphs.length; index += 1) {
      final painter = TextPainter(
        text: TextSpan(
          text: glyphs[index],
          style: TextStyle(color: color, fontSize: fontSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          topCenter.dx - painter.width / 2,
          topCenter.dy + centers[index] - painter.height / 2,
        ),
      );
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
