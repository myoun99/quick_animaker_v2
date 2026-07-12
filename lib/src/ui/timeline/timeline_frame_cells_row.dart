import 'package:flutter/material.dart';

import '../../models/camera_instruction.dart';
import '../../models/layer.dart';
import '../../services/audio/audio_peaks_extractor.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../../models/timeline_coverage.dart';
import 'timeline_block_move_handle.dart';
import 'timeline_cell_editor_policy.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_exposure_block_visual.dart';
import 'timeline_exposure_comma_drag_handle.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_cell.dart';
import 'timeline_frame_coordinate_policy.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_instruction_row_visual.dart';
import 'timeline_se_row_visual.dart';

/// One layer's row of frame cells. CURSOR-INDEPENDENT by design: nothing
/// here reads the playhead — the selected-cell ring, the selected-exposure
/// outline and the playhead tint live on the grid's TimelineCursorLayer,
/// so a frame tick never rebuilds this row (playback-performance
/// architecture).
class TimelineFrameCellsRow extends StatelessWidget {
  const TimelineFrameCellsRow({
    super.key,
    required this.layer,
    required this.active,
    required this.playbackFrameCount,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.leadingFrameSpacerWidth,
    required this.trailingFrameSpacerWidth,
    required this.metrics,
    required this.exposureStateForLayer,
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
    this.onActivateCell,
    this.instructionDefById,
    this.audioPeaksFor,
    this.projectFps = 24,
    this.onRemoveAudioClip,
    this.onDropMediaAsset,
    this.commaDrag,
    this.blockMove,
    this.baseLayer,
    this.sectionStart = false,
  });

  /// Whether this row opens a new timesheet section (drawing/SE/camera);
  /// draws a heavier divider along the row's top edge without changing the
  /// row geometry.
  final bool sectionStart;

  final Layer layer;
  final bool active;
  final int playbackFrameCount;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final TimelineGridMetrics metrics;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  /// Double-tap cell editor hook; only kinds that open an editor get it
  /// (policy: [layerKindOpensCellEditorOnDoubleTap]).
  final void Function(LayerId layerId, int frameIndex)? onActivateCell;

  /// Resolves instruction ids to their vocabulary defs for CAM row chips;
  /// null hides instruction overlays.
  final CameraInstructionDef? Function(String instructionId)?
  instructionDefById;

  /// Waveform peaks resolver for SE rows' audio clips; null hides them.
  final AudioPeaks? Function(String filePath)? audioPeaksFor;
  final int projectFps;

  /// Removes an audio clip by index (the waveform's context menu).
  final void Function(LayerId layerId, int clipIndex)? onRemoveAudioClip;

  /// Links a media-browser asset to an SE block (drag-drop); null hides
  /// the drop targets.
  final void Function(LayerId layerId, int blockStartFrame, String path)?
  onDropMediaAsset;

  /// Comma-drag hooks; null hides the block edge grips.
  final TimelineCommaDragCallbacks? commaDrag;

  /// Whole-block move hooks (R10-④b); null hides the block body handles.
  final TimelineBlockMoveHandleCallbacks? blockMove;

  /// The row's COMMITTED repository layer while [layer] carries a drag
  /// preview. The block-move handles mount from THIS one so a preview step
  /// (the block leaving for another row) never unmounts the handle that
  /// owns the live gesture (R12-③); null falls back to [layer].
  final Layer? baseLayer;

  @override
  Widget build(BuildContext context) {
    // Instruction rows have no timeline entries — adapt their events onto
    // the shared exposure states so the cells paint the same paper blocks.
    TimelineCellExposureState stateAt(int frameIndex) =>
        layer.kind == LayerKind.instruction
        ? instructionCellExposureState(layer, frameIndex)
        : exposureStateForLayer(layer, frameIndex);
    final commaDrag = this.commaDrag;
    final blockMove = this.blockMove;

    return Stack(
      key: ValueKey<String>('timeline-frame-row-area-${layer.id}'),
      children: [
        Row(
          children: [
            SizedBox(
              key: ValueKey<String>(
                'timeline-frame-row-leading-spacer-${layer.id}',
              ),
              width: leadingFrameSpacerWidth,
              height: metrics.layerRowHeight,
            ),
            for (
              var frameIndex = frameStartIndex;
              frameIndex < frameEndIndexExclusive;
              frameIndex += 1
            )
              TimelineFrameCell(
                layer: layer,
                frameIndex: frameIndex,
                width: metrics.frameCellWidth,
                height: metrics.layerRowHeight,
                active: active,
                outsidePlaybackRange: frameIndex >= playbackFrameCount,
                exposureState: stateAt(frameIndex),
                exposureBlockSegment:
                    calculateTimelineExposureBlockVisualSegment(
                      previous: frameIndex == 0
                          ? null
                          : stateAt(frameIndex - 1),
                      current: stateAt(frameIndex),
                      next: stateAt(frameIndex + 1),
                    ),
                emptyRunStart: timelineEmptyRunStartsAt(
                  current: stateAt(frameIndex),
                  previous: frameIndex == 0 ? null : stateAt(frameIndex - 1),
                ),
                frameName: frameNameForLayer?.call(layer, frameIndex),
                onSelectLayer: onSelectLayer,
                onSelectFrame: onSelectFrame,
                onActivateCell: layerKindOpensCellEditorOnDoubleTap(layer.kind)
                    ? onActivateCell
                    : null,
              ),
            SizedBox(
              key: ValueKey<String>(
                'timeline-frame-row-trailing-spacer-${layer.id}',
              ),
              width: trailingFrameSpacerWidth,
              height: metrics.layerRowHeight,
            ),
          ],
        ),
        if (sectionStart)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2,
            child: IgnorePointer(
              child: Container(
                key: ValueKey<String>(
                  'timeline-section-divider-row-${layer.id}',
                ),
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        // NO empty-stretch furniture here (R5-②): uncovered timeline cells
        // are already dark — the gray wash is print-sheet-only.
        // SE audio clips paint over the paper cells, under the writing —
        // clipped to the row's drawing blocks (no block, no waveform).
        if (layerKindUsesSeSheetCells(layer.kind) && audioPeaksFor != null)
          ...timelineRowAudioOverlays(
            layer: layer,
            frameStartIndex: frameStartIndex,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            frameCellExtent: metrics.frameCellWidth,
            crossAxisExtent: metrics.layerRowHeight,
            axis: Axis.horizontal,
            fps: projectFps,
            audioPeaksFor: audioPeaksFor!,
            onRemoveClip: onRemoveAudioClip == null
                ? null
                : (clipIndex) => onRemoveAudioClip!(layer.id, clipIndex),
            color: timelineDrawingInkColor.withValues(alpha: 0.22),
          ),
        // SE rows: the sheet's writing on the paper blocks — name box at
        // the block start plus the dialogue fitted across the span.
        if (layerKindUsesSeSheetCells(layer.kind))
          ...timelineRowSeLabelOverlays(
            layer: layer,
            frameStartIndex: frameStartIndex,
            frameEndIndexExclusive: frameEndIndexExclusive,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            frameCellExtent: metrics.frameCellWidth,
            crossAxisExtent: metrics.layerRowHeight,
            axis: Axis.horizontal,
          ),
        // Media-browser drops land on SE blocks (sound → block frame).
        if (layerKindUsesSeSheetCells(layer.kind) && onDropMediaAsset != null)
          ...timelineRowSeAssetDropTargets(
            layer: layer,
            frameStartIndex: frameStartIndex,
            frameEndIndexExclusive: frameEndIndexExclusive,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            frameCellExtent: metrics.frameCellWidth,
            crossAxisExtent: metrics.layerRowHeight,
            axis: Axis.horizontal,
            onAssetDropped: (blockStartFrame, path) =>
                onDropMediaAsset!(layer.id, blockStartFrame, path),
          ),
        // Instruction rows: the sheet's CAM column — bar arrows or the O.L
        // bowtie on the paper block, A → B endpoint values and the name
        // snapped to the anchor cell.
        if (layer.kind == LayerKind.instruction && instructionDefById != null)
          ...timelineRowInstructionOverlays(
            layer: layer,
            frameStartIndex: frameStartIndex,
            frameEndIndexExclusive: frameEndIndexExclusive,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            frameCellExtent: metrics.frameCellWidth,
            crossAxisExtent: metrics.layerRowHeight,
            axis: Axis.horizontal,
            defById: instructionDefById!,
          ),
        // Body handles mount UNDER the grips: the edges keep comma-drag
        // priority, the body between them moves the block whole.
        if (blockMove != null &&
            layerKindHoldsDrawings(layer.kind) &&
            !layerKindUsesSeSheetCells(layer.kind))
          ...timelineRowBlockMoveHandles(
            layerId: layer.id,
            blocks: drawingBlocks((baseLayer ?? layer).timeline),
            frameStartIndex: frameStartIndex,
            frameEndIndexExclusive: frameEndIndexExclusive,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            frameCellExtent: metrics.frameCellWidth,
            crossAxisExtent: metrics.layerRowHeight,
            callbacks: blockMove,
            axis: Axis.horizontal,
          ),
        if (commaDrag != null && layerKindHoldsDrawings(layer.kind))
          ...timelineRowBlockEdgeGrips(
            layer: layer,
            frameStartIndex: frameStartIndex,
            frameEndIndexExclusive: frameEndIndexExclusive,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            frameCellExtent: metrics.frameCellWidth,
            crossAxisExtent: metrics.layerRowHeight,
            commaDrag: commaDrag,
            axis: Axis.horizontal,
          ),
        if (commaDrag != null && layer.kind == LayerKind.instruction)
          ...timelineRowInstructionEdgeGrips(
            layer: layer,
            frameStartIndex: frameStartIndex,
            frameEndIndexExclusive: frameEndIndexExclusive,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            frameCellExtent: metrics.frameCellWidth,
            crossAxisExtent: metrics.layerRowHeight,
            commaDrag: commaDrag,
            axis: Axis.horizontal,
          ),
      ],
    );
  }
}

/// The edge grips for every drawing block intersecting the visible window,
/// shared by the horizontal row and the X-sheet column (Axis policy).
List<Widget> timelineRowBlockEdgeGrips({
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
  final blocks = drawingBlocks(layer.timeline);
  for (var ordinal = 0; ordinal < blocks.length; ordinal += 1) {
    final block = blocks[ordinal];
    if (block.endIndexExclusive <= frameStartIndex ||
        block.startIndex >= frameEndIndexExclusive) {
      continue;
    }

    final blockStartOffset = frameVisibleX(
      frameIndex: block.startIndex,
      frameStartIndex: frameStartIndex,
      frameCellWidth: frameCellExtent,
      leadingFrameSpacerWidth: leadingFrameSpacerWidth,
    );
    final blockEndOffset = frameVisibleX(
      frameIndex: block.endIndexExclusive,
      frameStartIndex: frameStartIndex,
      frameCellWidth: frameCellExtent,
      leadingFrameSpacerWidth: leadingFrameSpacerWidth,
    );

    for (final edge in TimelineBlockEdge.values) {
      grips.add(
        TimelineBlockEdgeGrip(
          layerId: layer.id,
          blockStartIndex: block.startIndex,
          blockOrdinal: ordinal,
          edge: edge,
          blockStartOffset: blockStartOffset,
          blockEndOffset: blockEndOffset,
          frameCellExtent: frameCellExtent,
          crossAxisExtent: crossAxisExtent,
          callbacks: commaDrag,
          axis: axis,
        ),
      );
    }
  }
  return grips;
}
