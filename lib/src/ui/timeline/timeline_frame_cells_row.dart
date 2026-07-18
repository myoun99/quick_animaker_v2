import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../models/camera_instruction.dart';
import '../../models/layer.dart';
import '../../services/audio/audio_peaks_extractor.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../../models/timeline_coverage.dart';
import 'timeline_cell_editor_policy.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_exposure_block_visual.dart';
import 'timeline_exposure_comma_drag_handle.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import '../../models/timeline_repeat.dart';
import 'timeline_frame_cell.dart';
import 'timeline_frame_coordinate_policy.dart';
import 'timeline_frame_range_gesture.dart';
import 'timeline_frame_window.dart';
import 'timeline_row_cells_painter.dart';
import 'timeline_run_end_handles.dart';
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
    this.rangeGesture,
    this.runEdit,
    this.baseLayer,
    this.seSpillsIn = false,
    this.windowBucket,
    this.viewportMainExtent = 0,
  });

  final Layer layer;
  final bool active;
  final int playbackFrameCount;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final TimelineGridMetrics metrics;

  /// PRO-TIMELINE scrolling (UI-R15→R16): with these set, the row builds
  /// ONCE for the FULL frame bounds — the painter windows itself off the
  /// quantized [windowBucket] (repaint once per span crossing, pure
  /// translation between), the sparse widget-cell kinds re-window their
  /// cells under the same bucket, and the overlays (grips, handles, SE
  /// writing) position content-absolutely. Null keeps the classic
  /// pre-windowed contract.
  final ValueListenable<int>? windowBucket;
  final double viewportMainExtent;
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

  /// The range select/move gesture bundle (UI-R8 — the block-body move
  /// handle's successor); null keeps the row display-only.
  final TimelineRangeGestureCallbacks? rangeGesture;

  /// The run-edge [+]/[↻] handle hooks (UI-R8); null hides the handles.
  final TimelineRunEditCallbacks? runEdit;

  /// The row's COMMITTED repository layer while [layer] carries a drag
  /// preview (kept for callers even though the range gesture layer mounts
  /// row-wide and never unmounts mid-preview); null falls back to [layer].
  final Layer? baseLayer;

  /// Track-SE rows whose display clone starts with a block spilling in
  /// from an earlier cut (UI-R7 #6): the cut start draws the `~`
  /// continuation and the block's start grip stands down (its real start
  /// lives in that earlier cut).
  final bool seSpillsIn;

  @override
  Widget build(BuildContext context) {
    // Instruction rows have no timeline entries — adapt their events onto
    // the shared exposure states so the cells paint the same paper blocks.
    TimelineCellExposureState stateAt(int frameIndex) =>
        layer.kind == LayerKind.instruction
        ? instructionCellExposureState(layer, frameIndex)
        : exposureStateForLayer(layer, frameIndex);
    final commaDrag = this.commaDrag;
    final rangeGesture = this.rangeGesture;

    return Stack(
      key: ValueKey<String>('timeline-frame-row-area-${layer.id}'),
      children: [
        // The dense drawing rows paint their cells as ONE CustomPaint
        // (UI-R9 #12b hybrid painterization); the sparse kinds (SE /
        // instruction / camera) keep the per-cell widget renderer their
        // overlays are built around.
        if (timelineRowUsesCellsPainter(layer.kind))
          timelineRowCellsPaintArea(
            context: context,
            keyPrefix: 'timeline',
            layer: layer,
            active: active,
            playbackFrameCount: playbackFrameCount,
            frameStartIndex: frameStartIndex,
            frameEndIndexExclusive: frameEndIndexExclusive,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            trailingFrameSpacerWidth: trailingFrameSpacerWidth,
            frameCellExtent: metrics.frameCellWidth,
            crossAxisExtent: metrics.layerRowHeight,
            axis: Axis.horizontal,
            windowBucket: windowBucket,
            viewportMainExtent: viewportMainExtent,
            exposureStateForLayer: exposureStateForLayer,
            frameNameForLayer: frameNameForLayer,
            onSelectLayer: onSelectLayer,
            onSelectFrame: onSelectFrame,
            onActivateCell: onActivateCell,
            suppressPointerDownSelect: rangeGesture == null
                ? null
                : (frameIndex) {
                    final selection = rangeGesture.selection.value;
                    return selection != null &&
                        selection.layerId == layer.id &&
                        selection.contains(frameIndex);
                  },
          )
        else if (windowBucket != null)
          // Sparse widget-cell kinds re-window their cells under the
          // bucket ALONE (UI-R15→R16): the row itself never rebuilds on
          // scroll — only this thin cell strip does, once per span
          // crossing (shared window policy).
          ValueListenableBuilder<int>(
            valueListenable: windowBucket!,
            builder: (context, bucket, _) {
              final cellExtent = metrics.frameCellWidth;
              final window = timelineFrameWindowFor(
                bucket: bucket,
                cellExtent: cellExtent,
                viewportExtent: viewportMainExtent,
              );
              final first = math.max(frameStartIndex, window.startIndex);
              final last = math.min(
                frameEndIndexExclusive,
                window.endIndexExclusive,
              );
              return _widgetCellsStrip(
                stateAt,
                startIndex: first,
                endIndexExclusive: math.max(first, last),
                leading: first * cellExtent,
                trailing:
                    (frameEndIndexExclusive - math.max(first, last)) *
                    cellExtent,
              );
            },
          )
        else
          _widgetCellsStrip(
            stateAt,
            startIndex: frameStartIndex,
            endIndexExclusive: frameEndIndexExclusive,
            leading: leadingFrameSpacerWidth,
            trailing: trailingFrameSpacerWidth,
          ),
        // NO extra section-divider overlay (R3 feedback #6): section
        // boundaries share the same single hairline as every row boundary;
        // the rail's gutter bracket carries the section identity.
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
        // Cut-boundary `~` marks (UI-R7 #6): a sound running past the cut
        // end / spilling in from the previous cut announces its other half.
        if (layerKindUsesSeSheetCells(layer.kind))
          ...timelineRowSeContinuationMarks(
            layer: layer,
            cutFrameCount: playbackFrameCount,
            spillsInAtStart: seSpillsIn,
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
        // The range gesture layer replaces the block-body move handle
        // (UI-R8, TVP style): a pan on the cells SELECTS a frame range —
        // a pan starting inside the current selection MOVES it. Mounted
        // UNDER the grips so the edges keep comma-drag priority. EVERY
        // layer row mounts it (UI-R20 #2: cells are cells — SE, camera
        // and instruction rows select too; what a selection can DO stays
        // kind-gated at the session seams).
        if (rangeGesture != null)
          TimelineFrameRangeGestureLayer(
            layer: layer,
            frameStartIndex: frameStartIndex,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            frameCellExtent: metrics.frameCellWidth,
            crossAxisExtent: metrics.layerRowHeight,
            callbacks: rangeGesture,
            axis: Axis.horizontal,
          ),
        // The TVP run-edge handles (UI-R8): [+] add-frames + [↻] repeat,
        // hugging each glued run's edges where space is free. Mounted from
        // the COMMITTED layer: the add-start preview shifts the run's
        // start, and a preview-derived mount would remount the handle
        // mid-gesture (R12-③ — the remount's dispose used to commit the
        // drag at one frame).
        if (runEdit != null &&
            layerKindHoldsDrawings(layer.kind) &&
            !layerKindUsesSeSheetCells(layer.kind))
          ...timelineRowRunEndHandles(
            // Display layer positions the clusters (they ride previews,
            // UI-R11 #1/#2); the committed base keeps their identity.
            layer: layer,
            baseLayer: baseLayer,
            frameStartIndex: frameStartIndex,
            frameEndIndexExclusive: frameEndIndexExclusive,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            frameCellExtent: metrics.frameCellWidth,
            crossAxisExtent: metrics.layerRowHeight,
            callbacks: runEdit!,
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
            // The spill-in block's `~` replaces its start grip (UI-R7 #6).
            suppressStartGripAtZero:
                seSpillsIn && layerKindUsesSeSheetCells(layer.kind),
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

  /// The sparse kinds' per-cell widget strip (SE / instruction / camera):
  /// spacers stand in for the cells outside [startIndex, endIndexExclusive).
  Widget _widgetCellsStrip(
    TimelineCellExposureState Function(int frameIndex) stateAt, {
    required int startIndex,
    required int endIndexExclusive,
    required double leading,
    required double trailing,
  }) {
    return Row(
      children: [
        SizedBox(
          key: ValueKey<String>(
            'timeline-frame-row-leading-spacer-${layer.id}',
          ),
          width: leading,
          height: metrics.layerRowHeight,
        ),
        for (
          var frameIndex = startIndex;
          frameIndex < endIndexExclusive;
          frameIndex += 1
        )
          TimelineFrameCell(
            layer: layer,
            frameIndex: frameIndex,
            width: metrics.frameCellWidth,
            height: metrics.layerRowHeight,
            active: active,
            outsidePlaybackRange: frameIndex >= playbackFrameCount,
            ghost: timelineIndexIsGhost(layer, frameIndex),
            exposureState: stateAt(frameIndex),
            exposureBlockSegment: calculateTimelineExposureBlockVisualSegment(
              previous: frameIndex == 0 ? null : stateAt(frameIndex - 1),
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
          width: trailing,
          height: metrics.layerRowHeight,
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
  bool suppressStartGripAtZero = false,
}) {
  final grips = <Widget>[];
  final blocks = drawingBlocks(layer.timeline);
  for (var ordinal = 0; ordinal < blocks.length; ordinal += 1) {
    final block = blocks[ordinal];
    if (block.endIndexExclusive <= frameStartIndex ||
        block.startIndex >= frameEndIndexExclusive) {
      continue;
    }
    // Ghost repeat instances are DERIVED — no timing grips (UI-R8).
    if (block.entry.ghost) {
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
      // The spill-in display block's start is not editable here — its real
      // start lives in an earlier cut (UI-R7 #6, TrackSeWindow contract).
      if (suppressStartGripAtZero &&
          edge == TimelineBlockEdge.start &&
          block.startIndex == 0) {
        continue;
      }
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
