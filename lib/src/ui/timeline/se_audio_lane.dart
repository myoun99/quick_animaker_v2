import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_kind.dart';
import '../../models/se_audio_spans.dart';
import '../../services/audio/audio_peaks_extractor.dart';
import '../audio/waveform_painter.dart';
import '../theme/app_theme.dart';
import 'property_lane_model.dart';
import 'timeline_cell_style.dart';
import 'timeline_frame_coordinate_policy.dart';
import 'timeline_grid_metrics.dart';

/// The SE audio lane: SE layers with sounds get ONE twirl-down lane — a
/// waveform editing strip where dragging a span along the frame axis
/// slides the sound inside its block (the clip's offsetFrames trim).
/// Shares the property-lane substrate (chevron, display rows, label cell)
/// but renders its own frame band; no key semantics.

const String seAudioLaneId = 'se-audio';

/// Whether [lane] is the SE audio lane (the display-row builders dispatch
/// the frame band on this).
bool laneIsSeAudio(PropertyLaneRow lane) => lane.laneId == seAudioLaneId;

/// The lanes an SE layer exposes: the audio lane while it carries sounds.
List<PropertyLaneRow> seAudioLanesFor(Layer layer) {
  if (layer.kind != LayerKind.se || layer.audioClips.isEmpty) {
    return const [];
  }
  return const [
    PropertyLaneRow(
      laneId: seAudioLaneId,
      label: 'Audio',
      keyedFrames: {},
      showsKeyNavigator: false,
    ),
  ];
}

/// The audio lane's frame band: one editable waveform window per audible
/// span, same geometry contract as TimelineLaneFrameRow (leading spacer +
/// band + trailing spacer, both orientations).
class SeAudioLaneFrameRow extends StatelessWidget {
  const SeAudioLaneFrameRow({
    super.key,
    required this.layer,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.leadingFrameSpacerWidth,
    required this.trailingFrameSpacerWidth,
    required this.metrics,
    required this.fps,
    this.audioPeaksFor,
    this.onSetClipOffset,
    this.axis = Axis.horizontal,
    this.keyPrefix = 'timeline',
  });

  final Layer layer;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final TimelineGridMetrics metrics;
  final int fps;
  final AudioPeaks? Function(String filePath)? audioPeaksFor;

  /// Commits a span's dragged offset (one undo); null makes the lane
  /// display-only.
  final void Function(int clipIndex, int offsetFrames)? onSetClipOffset;

  final Axis axis;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cellExtent = metrics.frameCellWidth;
    final crossExtent = metrics.layerRowHeight;
    final visibleExtent =
        (frameEndIndexExclusive - frameStartIndex) * cellExtent;
    final horizontal = axis == Axis.horizontal;

    final spans = <Widget>[];
    for (final span in seAudioSpans(layer)) {
      if (span.endFrameExclusive <= frameStartIndex ||
          span.startFrame >= frameEndIndexExclusive) {
        continue;
      }
      final startOffset = frameVisibleX(
        frameIndex: span.startFrame,
        frameStartIndex: frameStartIndex,
        frameCellWidth: cellExtent,
        leadingFrameSpacerWidth: 0,
      );
      final mainExtent = span.lengthFrames * cellExtent;
      final content = _SeAudioLaneSpan(
        key: ValueKey<String>(
          '$keyPrefix-audio-lane-span-${layer.id}-${span.clipIndex}'
          '-b${span.startFrame}',
        ),
        span: span,
        peaks: audioPeaksFor?.call(span.clip.filePath),
        fps: fps,
        frameCellExtent: cellExtent,
        axis: axis,
        onSetOffset: onSetClipOffset == null
            ? null
            : (offsetFrames) => onSetClipOffset!(span.clipIndex, offsetFrames),
      );
      spans.add(
        horizontal
            ? Positioned(
                left: startOffset,
                top: 0,
                width: mainExtent,
                height: crossExtent,
                child: content,
              )
            : Positioned(
                top: startOffset,
                left: 0,
                height: mainExtent,
                width: crossExtent,
                child: content,
              ),
      );
    }

    final band = DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
        border: horizontal
            ? Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 0.5,
                ),
              )
            : Border(
                right: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
      ),
      child: Stack(clipBehavior: Clip.hardEdge, children: spans),
    );

    if (horizontal) {
      return Row(
        key: ValueKey<String>('$keyPrefix-lane-row-${layer.id}-$seAudioLaneId'),
        children: [
          SizedBox(width: leadingFrameSpacerWidth, height: crossExtent),
          SizedBox(width: visibleExtent, height: crossExtent, child: band),
          SizedBox(width: trailingFrameSpacerWidth, height: crossExtent),
        ],
      );
    }
    return Column(
      key: ValueKey<String>('$keyPrefix-lane-row-${layer.id}-$seAudioLaneId'),
      children: [
        SizedBox(width: crossExtent, height: leadingFrameSpacerWidth),
        SizedBox(width: crossExtent, height: visibleExtent, child: band),
        SizedBox(width: crossExtent, height: trailingFrameSpacerWidth),
      ],
    );
  }
}

/// One span's editing window: paper block + the trimmed waveform. Dragging
/// along the frame axis slides the sound under the block — moving the
/// waveform left plays a LATER part of the file at the block start (offset
/// grows); live preview repaints only this span, release commits once.
class _SeAudioLaneSpan extends StatefulWidget {
  const _SeAudioLaneSpan({
    super.key,
    required this.span,
    required this.peaks,
    required this.fps,
    required this.frameCellExtent,
    required this.axis,
    required this.onSetOffset,
  });

  final SeAudioSpan span;
  final AudioPeaks? peaks;
  final int fps;
  final double frameCellExtent;
  final Axis axis;
  final ValueChanged<int>? onSetOffset;

  @override
  State<_SeAudioLaneSpan> createState() => _SeAudioLaneSpanState();
}

class _SeAudioLaneSpanState extends State<_SeAudioLaneSpan> {
  double _dragDelta = 0;
  bool _dragging = false;

  int get _fileFrames => widget.peaks?.durationFrames(widget.fps) ?? (1 << 20);

  /// The offset the current drag previews: dragging the waveform toward
  /// the span start (negative pixels) skips further into the file.
  int get _previewOffset {
    final base = widget.span.clip.offsetFrames;
    final deltaFrames = (-_dragDelta / widget.frameCellExtent).round();
    return (base + deltaFrames).clamp(0, math.max(0, _fileFrames - 1));
  }

  void _endDrag() {
    final committed = _previewOffset;
    setState(() {
      _dragging = false;
      _dragDelta = 0;
    });
    if (committed != widget.span.clip.offsetFrames) {
      widget.onSetOffset?.call(committed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    final peaks = widget.peaks;
    final offset = _dragging ? _previewOffset : widget.span.clip.offsetFrames;
    final editable = widget.onSetOffset != null && peaks != null;

    final children = <Widget>[
      // The block's paper backdrop so the lane reads as the block's own
      // editing strip.
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: timelineDrawingHeldColor.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            border: Border.all(color: timelineDrawingStartBorderColor),
          ),
        ),
      ),
      if (peaks != null)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: WaveformPainter(
                peaks: peaks,
                fps: widget.fps,
                pixelsPerFrame: widget.frameCellExtent,
                // Editing strip: stronger ink than the row's underlay.
                color: timelineDrawingInkColor.withValues(alpha: 0.45),
                axis: widget.axis,
                leadingFrames: offset,
              ),
            ),
          ),
        ),
      if (_dragging)
        Positioned(
          left: 4,
          top: 2,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Text(
                  '-${offset}f',
                  style: const TextStyle(fontSize: 9, color: Colors.black),
                ),
              ),
            ),
          ),
        ),
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // .down: the drag measures from the pointer-down origin, so the
      // recognizer's slop never eats into the slid amount.
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragStart: editable && horizontal
          ? (_) => setState(() => _dragging = true)
          : null,
      onHorizontalDragUpdate: editable && horizontal
          ? (details) => setState(() => _dragDelta += details.delta.dx)
          : null,
      onHorizontalDragEnd: editable && horizontal ? (_) => _endDrag() : null,
      onHorizontalDragCancel: editable && horizontal
          ? () => setState(() {
              _dragging = false;
              _dragDelta = 0;
            })
          : null,
      onVerticalDragStart: editable && !horizontal
          ? (_) => setState(() => _dragging = true)
          : null,
      onVerticalDragUpdate: editable && !horizontal
          ? (details) => setState(() => _dragDelta += details.delta.dy)
          : null,
      onVerticalDragEnd: editable && !horizontal ? (_) => _endDrag() : null,
      onVerticalDragCancel: editable && !horizontal
          ? () => setState(() {
              _dragging = false;
              _dragDelta = 0;
            })
          : null,
      child: MouseRegion(
        cursor: editable
            ? (horizontal
                  ? SystemMouseCursors.resizeLeftRight
                  : SystemMouseCursors.resizeUpDown)
            : MouseCursor.defer,
        child: Stack(clipBehavior: Clip.hardEdge, children: children),
      ),
    );
  }
}
