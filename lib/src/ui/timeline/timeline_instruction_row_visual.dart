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
/// overlay adds the mark background — the straight duration line
/// (A ⊢───⊣ B), the FI/FO hatched fade wedges or the O.L bowtie, per the
/// def's markType — with the instruction name at the span's START (unified
/// with frame blocks) and the A/B endpoint values at the span's ends.
/// Shared by both orientations (Axis policy).

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

  /// Endpoint values sit on the line's far side (below it on rows, right of
  /// it on X-sheet columns) — the sheet writes them beside the shaft.
  AlignmentGeometry get _valueAlignment =>
      axis == Axis.horizontal ? Alignment.bottomCenter : Alignment.centerRight;

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
    final valueStyle = TextStyle(
      color: timelineDrawingInkColor.withValues(alpha: 0.8),
      fontSize: 10,
      fontWeight: FontWeight.w600,
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
              alignment: _valueAlignment,
              child: ExcludeSemantics(child: _writing(valueA, valueStyle)),
            ),
          if (valueB != null && valueB.isNotEmpty)
            _cellSlot(
              cellIndex: event.length - 1,
              alignment: _valueAlignment,
              child: ExcludeSemantics(child: _writing(valueB, valueStyle)),
            ),
          // The name anchors to the span's START and runs along it, on the
          // line's near side — unified with frame blocks (user direction);
          // the sheet writes it the same way beside the shaft.
          if (name.isNotEmpty)
            Positioned.fill(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2, top: 1),
                  child: ExcludeSemantics(child: _writing(name, nameStyle)),
                ),
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

  @override
  void paint(Canvas canvas, Size size) {
    switch (markType) {
      case CameraInstructionMarkType.bar:
        _paintDurationLine(canvas, size);
      case CameraInstructionMarkType.fi:
        _paintFadeWedge(canvas, size, wideAtStart: true);
      case CameraInstructionMarkType.fo:
        _paintFadeWedge(canvas, size, wideAtStart: false);
      case CameraInstructionMarkType.ol:
        _paintBowtie(canvas, size);
    }
  }

  /// One completely straight line between the endpoint cells' centers with
  /// a perpendicular tick at each end; single-cell spans carry writing
  /// only, like on paper.
  void _paintDurationLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
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
    final tickExtent = (frameCellExtent * 0.14).clamp(2.5, 4.0);
    canvas.drawLine(_at(start, crossCenter), _at(end, crossCenter), paint);
    for (final main in [start, end]) {
      canvas.drawLine(
        _at(main, crossCenter - tickExtent),
        _at(main, crossCenter + tickExtent),
        paint,
      );
    }
  }

  /// The fade wedge: a hatched triangle spanning the whole event, full
  /// cross width where the screen is covered narrowing to a point where it
  /// is clear — FI narrows toward the span end, FO mirrors it.
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
    final wedge = Path()
      ..addPolygon([
        _at(wideMain, crossCenter - wideHalf),
        _at(pointMain, crossCenter),
        _at(wideMain, crossCenter + wideHalf),
      ], true);
    canvas.save();
    canvas.clipPath(wedge);
    final hatch = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    final bounds = wedge.getBounds();
    for (var x = bounds.left - bounds.height; x < bounds.right; x += 5.0) {
      canvas.drawLine(
        Offset(x, bounds.bottom),
        Offset(x + bounds.height, bounds.top),
        hatch,
      );
    }
    canvas.restore();
    canvas.drawPath(
      wedge,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintBowtie(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.18);
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
