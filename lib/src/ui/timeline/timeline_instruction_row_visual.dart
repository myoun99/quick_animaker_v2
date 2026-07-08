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
/// overlay adds the mark background — the bar arrows (A |←|←|← B) or the
/// O.L bowtie, per the def's markType — with the A/B endpoint values at the
/// span's ends and the instruction name snapped to the span's anchor cell.
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

/// The label anchor cell for an [eventLength]-frame span: odd spans center
/// exactly, even spans sit one cell left of the middle boundary — so the
/// writing always lands ON a cell like on paper (user-confirmed rule).
int instructionLabelAnchorCell(int eventLength) => (eventLength - 1) ~/ 2;

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

  /// One cell-sized slot at [cellIndex] holding centered [child]; the child
  /// may overflow the cell (paper writing spills over neighbours freely).
  Widget _cellSlot({required int cellIndex, required Widget child}) {
    final start = cellIndex * frameCellExtent;
    final overflowing = Center(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: child,
      ),
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
              child: ExcludeSemantics(child: _writing(valueA, valueStyle)),
            ),
          if (valueB != null && valueB.isNotEmpty)
            _cellSlot(
              cellIndex: event.length - 1,
              child: ExcludeSemantics(child: _writing(valueB, valueStyle)),
            ),
          if (name.isNotEmpty)
            _cellSlot(
              cellIndex: instructionLabelAnchorCell(event.length),
              child: ExcludeSemantics(child: _writing(name, nameStyle)),
            ),
        ],
      ),
    );
  }
}

/// The instruction mark background on the paper block: bar marks draw the
/// sheet's per-cell backward arrows (A |←|←|← B — head toward the span
/// start), O.L marks the translucent bowtie (two triangles meeting at the
/// span's center).
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

  @override
  void paint(Canvas canvas, Size size) {
    switch (markType) {
      case CameraInstructionMarkType.bar:
        _paintBarArrows(canvas, size);
      case CameraInstructionMarkType.ol:
        _paintBowtie(canvas, size);
    }
  }

  /// Backward arrows in the interior cells (the first and last cells hold
  /// the A/B writing); spans of one or two cells carry no arrows.
  void _paintBarArrows(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final crossCenter = axis == Axis.horizontal
        ? size.height / 2
        : size.width / 2;
    final headExtent = (frameCellExtent * 0.18).clamp(2.5, 5.0);
    final inset = (frameCellExtent * 0.2).clamp(2.0, 8.0);

    for (var cell = 1; cell < eventLength - 1; cell += 1) {
      final cellStart = cell * frameCellExtent;
      final tail = cellStart + frameCellExtent - inset;
      final head = cellStart + inset;
      if (tail - head < 2) {
        continue;
      }
      final (from, to) = axis == Axis.horizontal
          ? (Offset(tail, crossCenter), Offset(head, crossCenter))
          : (Offset(crossCenter, tail), Offset(crossCenter, head));
      canvas.drawLine(from, to, paint);
      // Arrowhead chevron at the head (toward the span start).
      final (wingA, wingB) = axis == Axis.horizontal
          ? (
              Offset(head + headExtent, crossCenter - headExtent),
              Offset(head + headExtent, crossCenter + headExtent),
            )
          : (
              Offset(crossCenter - headExtent, head + headExtent),
              Offset(crossCenter + headExtent, head + headExtent),
            );
      canvas.drawLine(to, wingA, paint);
      canvas.drawLine(to, wingB, paint);
    }
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
