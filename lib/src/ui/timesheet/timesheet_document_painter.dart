import 'dart:math' as math;

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
  /// reference ~140px) — completely open, no frames (R7-⑥). Printed on
  /// every page; page ink (S2) anchors on it.
  static const double memoBandHeight = 140;
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
  /// renormalizes the rest over the band. Proportions follow the user's
  /// reference sheets (R7-⑥): a slim Ep.no box, the Title clearly widest,
  /// then compact Cut/Duration/Name/Page boxes.
  static const Map<TimesheetHeaderField, double> _headerFieldFractions = {
    TimesheetHeaderField.episode: 0.08,
    TimesheetHeaderField.title: 0.32,
    TimesheetHeaderField.scene: 0.10,
    TimesheetHeaderField.cut: 0.11,
    TimesheetHeaderField.time: 0.12,
    TimesheetHeaderField.name: 0.17,
    TimesheetHeaderField.sheet: 0.10,
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
  });

  final TimesheetDocument document;
  final TimesheetDocumentLayout layout;
  final CanvasViewport? viewport;

  static const Color _paper = Color(0xFFF6F4F0);
  static const Color _ink = Color(0xFF33322F);
  static const Color _gridLight = Color(0xFFCFC9BF);
  static const Color _gridMedium = Color(0xFFA9A296);
  static const Color _gridBold = Color(0xFF6E6759);

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
  /// Ep.no | Title | Scene | Cut.no | Duration | Name | Page, minus hidden
  /// boxes. Reference-sheet layout (R7-⑥): the small gray label centers at
  /// the box top, the bold value centers underneath.
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
        Offset(box.rect.center.dx, box.rect.top + 5),
        fontSize: 8,
        color: _gridMedium,
        centeredAtX: true,
      );
      _text(
        canvas,
        _headerFieldValue(box.field, pageIndex),
        Offset(box.rect.center.dx, box.rect.top + 26),
        fontSize: 14,
        bold: true,
        centeredAtX: true,
        maxWidth: box.rect.width - 12,
      );
    }
  }

  /// The printed box label, the reference forms' wording (R7-⑥).
  static String headerFieldLabel(TimesheetHeaderField field) {
    return switch (field) {
      TimesheetHeaderField.episode => 'Ep.no',
      TimesheetHeaderField.title => 'Title',
      TimesheetHeaderField.scene => 'Scene',
      TimesheetHeaderField.cut => 'Cut.no',
      TimesheetHeaderField.time => 'Duration',
      TimesheetHeaderField.name => 'Name',
      TimesheetHeaderField.sheet => 'Page',
    };
  }

  String _headerFieldValue(TimesheetHeaderField field, int pageIndex) {
    return switch (field) {
      TimesheetHeaderField.episode => document.episode,
      TimesheetHeaderField.title => document.title,
      TimesheetHeaderField.scene => document.scene,
      TimesheetHeaderField.cut => document.cutName,
      // The sheet's 秒+コマ notation prints spaced ('2 + 6') like the
      // reference forms; the model label stays compact for row labels.
      TimesheetHeaderField.time => document.durationLabel.replaceAll(
        '+',
        ' + ',
      ),
      TimesheetHeaderField.name => document.artist,
      TimesheetHeaderField.sheet =>
        layout.continuous ? '1/1' : '${pageIndex + 1}/${document.pages.length}',
    };
  }

  /// The Direction memo band under the header: COMPLETELY open handwriting
  /// space, exactly like the reference forms (R7-⑥ — the band outline and
  /// the top-right memo box frame are both retired). The cut's Direction
  /// memo (cut note) types into its top left, spanning the full width.
  void _paintMemoBand(Canvas canvas, int pageIndex, {required bool drawTexts}) {
    if (!drawTexts) {
      return;
    }
    final band = layout.memoBandRect(pageIndex);
    if (document.memoText.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(
          text: document.memoText,
          style: const TextStyle(color: _ink, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 8,
        ellipsis: '…',
      )..layout(maxWidth: band.width - 16);
      painter.paint(canvas, Offset(band.left + 8, band.top + 6));
    }
    // NO derived instruction lines here anymore (R5-⑥): the shorthand
    // ('A→B PAN …') writes itself INTO the cut note once when the
    // instruction is created, so it prints above as ordinary — editable —
    // note text.
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
    // boundaries. SE columns print NO interior frame rules (R6-② — the
    // real Toei sheet leaves the S strip clean; its vertical borders and
    // the table's outer edges stay), so interior lines draw in segments
    // skipping the SE ranges.
    final seRanges = <(double, double)>[];
    for (var column = 0; column < document.columns.length; column += 1) {
      if (document.columns[column].kind != TimesheetColumnKind.se) {
        continue;
      }
      final seLeft = left + layout.columnLeftInHalf(column);
      final seRight = seLeft + layout.columnWidthFor(TimesheetColumnKind.se);
      if (seRanges.isNotEmpty && seRanges.last.$2 >= seLeft) {
        seRanges[seRanges.length - 1] = (seRanges.last.$1, seRight);
      } else {
        seRanges.add((seLeft, seRight));
      }
    }
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
      if (row == 0 || row == rowCount || seRanges.isEmpty) {
        // The table's outer edges close full width.
        canvas.drawLine(Offset(left, y), Offset(right, y), paint);
        continue;
      }
      var segmentStart = left;
      for (final (seLeft, seRight) in seRanges) {
        if (seLeft > segmentStart) {
          canvas.drawLine(Offset(segmentStart, y), Offset(seLeft, y), paint);
        }
        segmentStart = seRight;
      }
      if (segmentStart < right) {
        canvas.drawLine(Offset(segmentStart, y), Offset(right, y), paint);
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
              // block's END closes with the full-width red bar instead.
              if ((cell.spanOffset ?? 0) == (cell.spanLength ?? 1) - 1) {
                _paintSeRedBar(
                  canvas,
                  columnLeft: columnLeft,
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
    final spanLength = cell.spanLength ?? 1;
    final offset = cell.spanOffset ?? 0;
    final isFirst = offset == 0;
    final isLast = offset == spanLength - 1;

    if ((cell.markType ?? CameraInstructionMarkType.bar) ==
        CameraInstructionMarkType.bar) {
      // R5-⑤: the endpoint cells carry NO line — the names own them. Each
      // row between draws edge to edge (R6-①a: the per-cell padding made
      // the bar read as broken dashes), thin like a ruled sheet line. A
      // NAMELESS endpoint carries the solid triangle cap instead (real
      // sheets, R7-①) and the line runs through its row to meet it.
      final linePaint = Paint()
        ..color = _ink
        ..strokeWidth = 0.9;
      final hasA = (cell.valueA ?? '').isNotEmpty;
      final hasB = (cell.valueB ?? '').isNotEmpty;
      final triangleLength = math.min(
        7.0,
        TimesheetDocumentLayout.rowHeight - 4,
      );
      if (!isFirst && !isLast) {
        canvas.drawLine(
          Offset(centerX, cellTop),
          Offset(centerX, cellBottom),
          linePaint,
        );
      } else if (isFirst && isLast) {
        if (!hasA && !hasB) {
          // Single-row nameless span: both caps in the one cell (▼ over ▲).
          _paintBarEndpointTriangle(
            canvas,
            centerX: centerX,
            columnWidth: columnWidth,
            baseY: cellTop,
            apexDown: true,
          );
          _paintBarEndpointTriangle(
            canvas,
            centerX: centerX,
            columnWidth: columnWidth,
            baseY: cellBottom,
            apexDown: false,
          );
        }
      } else if (isFirst) {
        if (!hasA) {
          _paintBarEndpointTriangle(
            canvas,
            centerX: centerX,
            columnWidth: columnWidth,
            baseY: cellTop,
            apexDown: true,
          );
          canvas.drawLine(
            Offset(centerX, cellTop + triangleLength),
            Offset(centerX, cellBottom),
            linePaint,
          );
        }
      } else if (!hasB) {
        _paintBarEndpointTriangle(
          canvas,
          centerX: centerX,
          columnWidth: columnWidth,
          baseY: cellBottom,
          apexDown: false,
        );
        canvas.drawLine(
          Offset(centerX, cellTop),
          Offset(centerX, cellBottom - triangleLength),
          linePaint,
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
    // Writing goes BOLD (R6-①a): it sits directly on the bar/mark and has
    // to stay readable over it.
    if (isFirst && (cell.valueA ?? '').isNotEmpty) {
      _text(
        canvas,
        cell.valueA!,
        Offset(centerX, cellTop + 3),
        fontSize: 10,
        bold: true,
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
        bold: true,
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
        bold: true,
        color: _ink,
        centeredAtX: true,
        maxWidth: columnWidth - 2,
      );
    }
    if (offset == (spanLength - 1) ~/ 2 && (cell.label ?? '').isNotEmpty) {
      // The writing sits on the SPAN's true center, HORIZONTAL (R5-⑤ —
      // the vertical glyph stack retired), overlaid on the mark and
      // spilling over neighbouring columns freely like handwriting.
      final spanTop = cellTop - offset * rowHeight;
      final painter = TextPainter(
        text: TextSpan(
          text: cell.label!,
          style: const TextStyle(
            color: _ink,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          centerX - painter.width / 2,
          spanTop + spanLength * rowHeight / 2 - painter.height / 2,
        ),
      );
    }
  }

  /// The solid triangle capping a NAMELESS bar endpoint (R7-①, real-sheet
  /// convention), APEX pointing INTO the span (R8-① direction fix): the
  /// start cap reads ▼ from the span's top edge, the end cap ▲ from its
  /// bottom edge — both bases sit FLUSH on the cell edge (compact, no
  /// inset). The duration line meets the apex. Mirrors the X-sheet
  /// overlay's mark.
  void _paintBarEndpointTriangle(
    Canvas canvas, {
    required double centerX,
    required double columnWidth,
    required double baseY,
    required bool apexDown,
  }) {
    final length = math.min(7.0, TimesheetDocumentLayout.rowHeight - 4);
    final halfWidth = math.min(4.0, columnWidth / 2 - 2);
    final apexY = apexDown ? baseY + length : baseY - length;
    canvas.drawPath(
      Path()..addPolygon([
        Offset(centerX - halfWidth, baseY),
        Offset(centerX, apexY),
        Offset(centerX + halfWidth, baseY),
      ], true),
      Paint()..color = _ink,
    );
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

  /// An SE entry's start cell (R5-⑦, user-approved mockup v4): a full-width
  /// thin red bar RIGHT BEFORE the block start, a compact ACCENT name box
  /// (the app's shared accent — same chip as the timeline/X-sheet rows)
  /// hugging the boundary, the dialogue distributed vertically over the
  /// REST of the span — no duration bar. Single-row entries close with the
  /// red end bar right here; longer ones close from their last held row.
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

    // The opening red bar sits ON the start boundary only when this row
    // really is the span's first (page-half continuations skip it).
    if ((cell.spanOffset ?? 0) == 0) {
      _paintSeRedBar(
        canvas,
        columnLeft: columnLeft,
        columnWidth: columnWidth,
        y: cellTop + 1,
      );
    }

    var dialogueTop = cellTop + 3;
    if (seName.isNotEmpty) {
      // R6-②: a soft accent tint with dark ink writing — the full-strength
      // accent read too loud against the paper. FULL column width (R7-②:
      // the name box, the red bars and the SE column must share ONE exact
      // width — the old 1px inset read as a mismatched overlay).
      canvas.drawRect(
        Rect.fromLTWH(columnLeft, cellTop + 2, columnWidth, nameBoxHeight),
        Paint()..color = AppColors.accent.withValues(alpha: 0.3),
      );
      _text(
        canvas,
        seName,
        Offset(centerX, cellTop + 4),
        fontSize: 7,
        bold: true,
        color: _ink,
        centeredAtX: true,
        maxWidth: columnWidth - 4,
      );
      dialogueTop = cellTop + nameBoxHeight + 4;
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
      _paintSeRedBar(
        canvas,
        columnLeft: columnLeft,
        columnWidth: columnWidth,
        y: spanBottom - 1,
      );
    }
  }

  /// The full-width thin red bar closing an SE block (and mirrored before
  /// its start) — Toei notation, R5-⑦: frame-width, not a short tick. ONE
  /// geometry with the name box and the SE column itself (R7-②).
  void _paintSeRedBar(
    Canvas canvas, {
    required double columnLeft,
    required double columnWidth,
    required double y,
  }) {
    canvas.drawLine(
      Offset(columnLeft, y),
      Offset(columnLeft + columnWidth, y),
      Paint()
        ..color = AppColors.danger
        ..strokeWidth = 2,
    );
  }

  /// An SE column's empty row: the light-gray "no SE here" wash (project
  /// toggle). Print-sheet only — the timeline/X-sheet's dark uncovered
  /// cells already read as empty, and the dotted center guide is retired
  /// everywhere (R5-②).
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
  }

  /// An upright glyph stack centered on [center] (the instruction writing
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
        oldDelegate.viewport != viewport;
  }
}

/// The sheet's PLAYHEAD row highlight as its own repaint-only layer
/// (R13-2: the cursor-layer discipline, timesheet edition). The playhead
/// used to be a parameter of [TimesheetDocumentPainter], so every cursor
/// move, committed seek and playback tick re-recorded the ENTIRE B4 sheet
/// — with the timesheet docked visible that repaint was the biggest
/// single share of the frame-flip hitch. This painter repaints one rect
/// through [CustomPainter.repaint]; the sheet above never hears about the
/// playhead at all.
class TimesheetPlayheadPainter extends CustomPainter {
  TimesheetPlayheadPainter({
    required this.document,
    required this.layout,
    required this.resolvePlayheadFrame,
    this.viewport,
    super.repaint,
  });

  final TimesheetDocument document;
  final TimesheetDocumentLayout layout;

  /// Reads the CURRENT playhead frame at paint time (the repaint
  /// listenable drives when that happens).
  final int? Function() resolvePlayheadFrame;
  final CanvasViewport? viewport;

  static const Color _playhead = Color(0x334FA8A0);

  @override
  void paint(Canvas canvas, Size size) {
    final frame = resolvePlayheadFrame();
    if (frame == null || frame < 0 || frame >= document.rowCount) {
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final resolvedViewport = viewport;
    if (resolvedViewport != null) {
      canvas.translate(resolvedViewport.panX, resolvedViewport.panY);
      canvas.scale(resolvedViewport.zoom, resolvedViewport.zoom);
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
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TimesheetPlayheadPainter oldDelegate) {
    return !identical(oldDelegate.document, document) ||
        oldDelegate.layout.continuous != layout.continuous ||
        oldDelegate.viewport != viewport;
  }
}
