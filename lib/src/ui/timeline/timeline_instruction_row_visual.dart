import 'package:flutter/material.dart';

import '../../models/camera_instruction.dart';
import '../../models/layer.dart';
import '../../models/timeline_coverage.dart' show TimelineBlockEdge;
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_exposure_comma_drag_handle.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_coordinate_policy.dart';

/// Instruction rows render like the paper sheet's CAM column on white
/// frame blocks: the cells paint the paper (via
/// [instructionCellExposureState] feeding the shared cell style), this
/// overlay adds the mark — ONE unadorned continuous line for bar terms
/// (no end ticks, never broken for text) or a light-gray filled wedge for
/// the dedicated FI/FO/O.L marks (R4, user sketch) — with the A/B
/// instance names dead-centered in the start/end cells (frame-name style)
/// and the instruction name overlaid on the SPAN's true center. Shared by
/// both orientations (Axis policy); the printed sheet mirrors this
/// verbatim.

/// Paper-cell adapter: instruction events have no timeline entries, so
/// this maps a frame index onto the shared cell exposure states (span
/// start → drawingStart, covered → held) — the cells then paint the same
/// paper blocks, borders and rounding as drawing rows.
TimelineCellExposureState instructionCellExposureState(
  Layer layer,
  int frameIndex,
) {
  final instructions = layer.instructions;
  if (frameIndex < 0) {
    return TimelineCellExposureState.uncovered;
  }
  if (instructions.containsKey(frameIndex)) {
    return TimelineCellExposureState.drawingStart;
  }
  final startKey = instructions.lastKeyBefore(frameIndex);
  if (startKey == null) {
    return TimelineCellExposureState.uncovered;
  }
  final event = instructions[startKey]!;
  return frameIndex < startKey + event.length
      ? TimelineCellExposureState.held
      : TimelineCellExposureState.uncovered;
}

/// The mark/label overlays for every instruction span intersecting the
/// visible window.
List<Widget> timelineRowInstructionOverlays({
  required Layer layer,
  required int frameStartIndex,
  required int frameEndIndexExclusive,
  required double leadingFrameSpacerWidth,
  required double frameCellExtent,
  required double crossAxisExtent,
  required Axis axis,
  required CameraInstructionDef? Function(String instructionId) defById,
  String keyPrefix = 'timeline',
}) {
  final overlays = <Widget>[];
  for (final entry in layer.instructions.entries) {
    final start = entry.key;
    final endExclusive = start + entry.value.length;
    if (endExclusive <= frameStartIndex || start >= frameEndIndexExclusive) {
      continue;
    }

    final startOffset = frameVisibleX(
      frameIndex: start,
      frameStartIndex: frameStartIndex,
      frameCellWidth: frameCellExtent,
      leadingFrameSpacerWidth: leadingFrameSpacerWidth,
    );
    final endOffset = frameVisibleX(
      frameIndex: endExclusive,
      frameStartIndex: frameStartIndex,
      frameCellWidth: frameCellExtent,
      leadingFrameSpacerWidth: leadingFrameSpacerWidth,
    );
    final mainExtent = endOffset - startOffset;
    final def = defById(entry.value.instructionId);

    final content = IgnorePointer(
      key: ValueKey<String>('$keyPrefix-instruction-${layer.id}-$start'),
      child: _InstructionSpan(
        axis: axis,
        event: entry.value,
        def: def,
        frameCellExtent: frameCellExtent,
      ),
    );

    overlays.add(switch (axis) {
      Axis.horizontal => Positioned(
        left: startOffset,
        top: 0,
        width: mainExtent,
        height: crossAxisExtent,
        child: content,
      ),
      Axis.vertical => Positioned(
        top: startOffset,
        left: 0,
        height: mainExtent,
        width: crossAxisExtent,
        child: content,
      ),
    });
  }
  return overlays;
}

/// Edge grips over instruction spans: reuses the exposure grip widget and
/// callback shape — the session dispatches instruction rows to the span
/// editor internally, so both row types share one drag pipeline.
List<Widget> timelineRowInstructionEdgeGrips({
  required Layer layer,
  required int frameStartIndex,
  required int frameEndIndexExclusive,
  required double leadingFrameSpacerWidth,
  required double frameCellExtent,
  required double crossAxisExtent,
  required TimelineCommaDragCallbacks commaDrag,
  required Axis axis,
}) {
  final grips = <Widget>[];
  var ordinal = 0;
  for (final entry in layer.instructions.entries) {
    final start = entry.key;
    final endExclusive = start + entry.value.length;
    final visible =
        endExclusive > frameStartIndex && start < frameEndIndexExclusive;
    if (visible) {
      final startOffset = frameVisibleX(
        frameIndex: start,
        frameStartIndex: frameStartIndex,
        frameCellWidth: frameCellExtent,
        leadingFrameSpacerWidth: leadingFrameSpacerWidth,
      );
      final endOffset = frameVisibleX(
        frameIndex: endExclusive,
        frameStartIndex: frameStartIndex,
        frameCellWidth: frameCellExtent,
        leadingFrameSpacerWidth: leadingFrameSpacerWidth,
      );
      for (final edge in TimelineBlockEdge.values) {
        grips.add(
          TimelineBlockEdgeGrip(
            layerId: layer.id,
            blockStartIndex: start,
            blockOrdinal: ordinal,
            edge: edge,
            blockStartOffset: startOffset,
            blockEndOffset: endOffset,
            frameCellExtent: frameCellExtent,
            crossAxisExtent: crossAxisExtent,
            callbacks: commaDrag,
            axis: axis,
          ),
        );
      }
    }
    ordinal += 1;
  }
  return grips;
}

class _InstructionSpan extends StatelessWidget {
  const _InstructionSpan({
    required this.axis,
    required this.event,
    required this.def,
    required this.frameCellExtent,
  });

  final Axis axis;
  final InstructionEvent event;
  final CameraInstructionDef? def;
  final double frameCellExtent;

  /// One cell-sized slot at [cellIndex] holding [child] at [alignment]; the
  /// child may overflow the cell (paper writing spills over neighbours
  /// freely).
  Widget _cellSlot({
    required int cellIndex,
    required Widget child,
    AlignmentGeometry alignment = Alignment.center,
  }) {
    final start = cellIndex * frameCellExtent;
    final overflowing = OverflowBox(
      alignment: alignment,
      // BOTH bounds must open up: OverflowBox only replaces what is set,
      // and the Positioned slot's TIGHT mins otherwise force the writing
      // to fill the slot — glyphs then paint from the start edge and the
      // labels LOOK top/left-aligned instead of centered (R5-⑤ root
      // cause, all three misalignment reports).
      minWidth: 0,
      minHeight: 0,
      maxWidth: double.infinity,
      maxHeight: double.infinity,
      child: child,
    );
    return switch (axis) {
      Axis.horizontal => Positioned(
        left: start,
        top: 0,
        bottom: 0,
        width: frameCellExtent,
        child: overflowing,
      ),
      Axis.vertical => Positioned(
        top: start,
        left: 0,
        right: 0,
        height: frameCellExtent,
        child: overflowing,
      ),
    };
  }

  /// Writing runs along the frame axis: plain text on horizontal rows, an
  /// upright glyph stack (paper-style vertical writing, never rotated) on
  /// X-sheet columns.
  Widget _writing(String text, TextStyle style) {
    if (axis == Axis.horizontal) {
      return Text(text, maxLines: 1, softWrap: false, style: style);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final glyph in text.characters) Text(glyph, style: style),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final markColor = def?.colorValue == null
        ? timelineDrawingInkColor
        : Color(def!.colorValue!);
    // The mark and the writing are independent: free per-event text wins,
    // the vocabulary name is the fallback.
    final name = event.displayLabel(def);
    // The A/B instance names read exactly like frame names on drawing
    // blocks: ink, bold, ambient size, centered in their cells.
    const valueStyle = TextStyle(
      color: timelineDrawingInkColor,
      fontWeight: FontWeight.bold,
      height: 1.1,
    );
    final nameStyle = TextStyle(
      color: markColor,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      height: 1.1,
    );
    final valueA = event.valueA;
    final valueB = event.valueB;

    return Semantics(
      label: [
        'instruction $name',
        if (event.valueA != null) 'from ${event.valueA}',
        if (event.valueB != null) 'to ${event.valueB}',
      ].join(' '),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _InstructionMarkPainter(
                  axis: axis,
                  markType: def?.markType ?? CameraInstructionMarkType.bar,
                  eventLength: event.length,
                  frameCellExtent: frameCellExtent,
                  color: markColor,
                ),
              ),
            ),
          ),
          if (valueA != null && valueA.isNotEmpty)
            _cellSlot(
              cellIndex: 0,
              child: ExcludeSemantics(child: _writing(valueA, valueStyle)),
            ),
          if (valueB != null && valueB.isNotEmpty)
            _cellSlot(
              cellIndex: event.length - 1,
              child: ExcludeSemantics(child: _writing(valueB, valueStyle)),
            ),
          // The name overlays the SPAN's true center, written over the
          // line/wedge (R4: the cell-snap anchor is retired — labels sit
          // dead center like handwriting on the sheet).
          if (name.isNotEmpty)
            Positioned.fill(
              child: OverflowBox(
                // Open mins too (see _cellSlot) — otherwise the name fills
                // the span and its glyphs paint from the FIRST frame
                // instead of sitting on the span's center.
                minWidth: 0,
                minHeight: 0,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: ExcludeSemantics(child: _writing(name, nameStyle)),
              ),
            ),
        ],
      ),
    );
  }
}

/// The instruction mark background on the paper block: bar marks draw the
/// sheet's completely straight duration line with a perpendicular tick at
/// each end (A ⊢───⊣ B — no arrowheads, user-confirmed), FI/FO the hatched
/// fade wedges (wide where the screen is covered), O.L the translucent
/// bowtie (two triangles meeting at the span's center).
class _InstructionMarkPainter extends CustomPainter {
  _InstructionMarkPainter({
    required this.axis,
    required this.markType,
    required this.eventLength,
    required this.frameCellExtent,
    required this.color,
  });

  final Axis axis;
  final CameraInstructionMarkType markType;
  final int eventLength;
  final double frameCellExtent;
  final Color color;

  /// Main/cross coordinates → canvas offset for the current [axis].
  Offset _at(double main, double cross) =>
      axis == Axis.horizontal ? Offset(main, cross) : Offset(cross, main);

  /// The dedicated marks' light-gray fill — laid under the writing, with
  /// the cell borders showing through (R4: hatching and outlines retired).
  Paint get _wedgeFill => Paint()..color = color.withValues(alpha: 0.15);

  @override
  void paint(Canvas canvas, Size size) {
    switch (markType) {
      case CameraInstructionMarkType.bar:
        _paintDurationLine(canvas, size);
      case CameraInstructionMarkType.fi:
        _paintFadeWedge(canvas, size, wideAtStart: false);
      case CameraInstructionMarkType.fo:
        _paintFadeWedge(canvas, size, wideAtStart: true);
      case CameraInstructionMarkType.ol:
        _paintBowtie(canvas, size);
    }
  }

  /// ONE unadorned continuous line between the endpoint cells' centers —
  /// no end ticks and no gap for the writing (the name overlays it, R4
  /// user rule); single-cell spans carry writing only, like on paper.
  void _paintDurationLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final mainExtent = axis == Axis.horizontal ? size.width : size.height;
    final crossCenter = axis == Axis.horizontal
        ? size.height / 2
        : size.width / 2;
    final start = frameCellExtent / 2;
    final end = mainExtent - frameCellExtent / 2;
    if (end - start < 2) {
      return;
    }
    canvas.drawLine(_at(start, crossCenter), _at(end, crossCenter), paint);
  }

  /// The fade wedge, a plain light-gray fill following the light: FI opens
  /// narrow → wide (the picture grows in), FO wide → narrow (R4
  /// orientation fix; hatching retired).
  void _paintFadeWedge(Canvas canvas, Size size, {required bool wideAtStart}) {
    final mainExtent = axis == Axis.horizontal ? size.width : size.height;
    final crossExtent = axis == Axis.horizontal ? size.height : size.width;
    final crossCenter = crossExtent / 2;
    final wideHalf = crossCenter - 2;
    if (mainExtent < 6 || wideHalf < 2) {
      return;
    }
    final wideMain = wideAtStart ? 1.0 : mainExtent - 1;
    final pointMain = wideAtStart ? mainExtent - 1 : 1.0;
    canvas.drawPath(
      Path()..addPolygon([
        _at(wideMain, crossCenter - wideHalf),
        _at(pointMain, crossCenter),
        _at(wideMain, crossCenter + wideHalf),
      ], true),
      _wedgeFill,
    );
  }

  void _paintBowtie(Canvas canvas, Size size) {
    final paint = _wedgeFill;
    final mainExtent = axis == Axis.horizontal ? size.width : size.height;
    final mid = mainExtent / 2;
    final startTriangle = Path();
    final endTriangle = Path();
    if (axis == Axis.horizontal) {
      startTriangle
        ..moveTo(0, 0)
        ..lineTo(mid, size.height / 2)
        ..lineTo(0, size.height)
        ..close();
      endTriangle
        ..moveTo(size.width, 0)
        ..lineTo(mid, size.height / 2)
        ..lineTo(size.width, size.height)
        ..close();
    } else {
      startTriangle
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, mid)
        ..lineTo(size.width, 0)
        ..close();
      endTriangle
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, mid)
        ..lineTo(size.width, size.height)
        ..close();
    }
    canvas.drawPath(startTriangle, paint);
    canvas.drawPath(endTriangle, paint);
  }

  @override
  bool shouldRepaint(_InstructionMarkPainter oldDelegate) {
    return axis != oldDelegate.axis ||
        markType != oldDelegate.markType ||
        eventLength != oldDelegate.eventLength ||
        frameCellExtent != oldDelegate.frameCellExtent ||
        color != oldDelegate.color;
  }
}
