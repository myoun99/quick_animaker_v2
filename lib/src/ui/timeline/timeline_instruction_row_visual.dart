import 'package:flutter/material.dart';

import '../../models/camera_instruction.dart';
import '../../models/layer.dart';
import '../../models/timeline_coverage.dart';
import 'instruction_icon_palette.dart';
import 'timeline_exposure_comma_drag_handle.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_coordinate_policy.dart';

/// Instruction rows read like the sheet's CAM column: each event shows its
/// [icon + name] chip at the start, the A endpoint value, a span line to
/// the event's end with the B value and a closing tick. Shared by both
/// orientations (Axis policy), mirroring the SE row overlay approach.

/// The chip/line overlays for every instruction span intersecting the
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
  required Color textColor,
  required Color lineColor,
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
        textColor: textColor,
        lineColor: lineColor,
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
    required this.textColor,
    required this.lineColor,
  });

  final Axis axis;
  final InstructionEvent event;
  final CameraInstructionDef? def;
  final Color textColor;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final accent = def?.colorValue == null
        ? textColor
        : Color(def!.colorValue!);
    final name = def?.name ?? event.instructionId;
    final valueStyle = TextStyle(
      color: textColor.withValues(alpha: 0.75),
      fontSize: 10,
    );

    final chip = Padding(
      padding: axis == Axis.horizontal
          ? const EdgeInsets.symmetric(horizontal: 4)
          : const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              def == null
                  ? instructionFallbackIcon
                  : instructionIconFor(def!.iconKey),
              size: 14,
              color: accent,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final line = Expanded(
      child: Center(
        child: Container(
          width: axis == Axis.horizontal ? null : 1.6,
          height: axis == Axis.horizontal ? 1.6 : null,
          color: lineColor,
        ),
      ),
    );
    final endTick = Container(
      width: axis == Axis.horizontal ? 2 : 9,
      height: axis == Axis.horizontal ? 9 : 2,
      margin: axis == Axis.horizontal
          ? const EdgeInsets.only(right: 3)
          : const EdgeInsets.only(bottom: 3),
      color: lineColor,
    );

    return Semantics(
      label: [
        'instruction $name',
        if (event.valueA != null) 'from ${event.valueA}',
        if (event.valueB != null) 'to ${event.valueB}',
      ].join(' '),
      child: Flex(
        direction: axis,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: chip),
          if (event.valueA != null && event.valueA!.isNotEmpty)
            Flexible(
              child: ExcludeSemantics(
                child: Text(
                  event.valueA!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ),
            ),
          line,
          if (event.valueB != null && event.valueB!.isNotEmpty)
            Flexible(
              child: Padding(
                padding: axis == Axis.horizontal
                    ? const EdgeInsets.only(right: 2)
                    : const EdgeInsets.only(bottom: 2),
                child: ExcludeSemantics(
                  child: Text(
                    event.valueB!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  ),
                ),
              ),
            ),
          endTick,
        ],
      ),
    );
  }
}
