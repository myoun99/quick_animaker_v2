import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/camera_instruction.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../../services/audio/audio_peaks_extractor.dart';
import 'property_lane_model.dart';
import 'se_audio_lane.dart';
import 'timeline_block_move_handle.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_drag_preview.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_cells_row.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_lane_rows.dart';

class TimelineFrameRowsScrollBody extends StatefulWidget {
  const TimelineFrameRowsScrollBody({
    super.key,
    required this.rows,
    required this.activeLayerId,
    required this.playbackFrameCount,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.leadingFrameSpacerWidth,
    required this.trailingFrameSpacerWidth,
    required this.totalFrameContentWidth,
    this.leadingLayerSpacerHeight = 0,
    this.trailingLayerSpacerHeight = 0,
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
    this.onSetAudioClipOffset,
    this.audioOffsetDrag,
    this.onSetAudioClipFades,
    this.onSetAudioClipGain,
    this.commaDrag,
    this.blockMove,
    this.laneEdit,
    this.dragPreview,
  });

  /// Display rows: layer rows interleaved with expanded property lanes.
  /// May be a layer-axis WINDOW of the full row list — the spacer heights
  /// preserve the scroll geometry of the rows sliced away.
  final List<TimelineDisplayRow> rows;
  final LayerId? activeLayerId;
  final int playbackFrameCount;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final double totalFrameContentWidth;

  /// Layer-axis spacers standing in for the rows above/below the built
  /// window (the vertical counterpart of the frame-axis spacers).
  final double leadingLayerSpacerHeight;
  final double trailingLayerSpacerHeight;

  final TimelineGridMetrics metrics;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;
  final void Function(LayerId layerId, int frameIndex)? onActivateCell;
  final CameraInstructionDef? Function(String instructionId)?
  instructionDefById;
  final AudioPeaks? Function(String filePath)? audioPeaksFor;
  final int projectFps;
  final void Function(LayerId layerId, int clipIndex)? onRemoveAudioClip;
  final void Function(LayerId layerId, int blockStartFrame, String path)?
  onDropMediaAsset;

  /// Commits an audio-lane slide (the clip's offset trim); null makes the
  /// audio lane display-only.
  final void Function(LayerId layerId, int clipIndex, int offsetFrames)?
  onSetAudioClipOffset;

  /// Live drag session for the slide (repo-direct preview + one undo on
  /// release); falls back to the local preview + [onSetAudioClipOffset].
  final AudioOffsetDragCallbacks? audioOffsetDrag;

  /// Commits an audio-lane fade-handle drag; null hides the handles.
  final void Function(
    LayerId layerId,
    int clipIndex,
    int fadeInFrames,
    int fadeOutFrames,
  )?
  onSetAudioClipFades;

  /// Commits the audio-lane gain dialog; null hides the menu entry.
  final void Function(LayerId layerId, int clipIndex, double gain)?
  onSetAudioClipGain;

  final TimelineCommaDragCallbacks? commaDrag;

  /// Whole-block move hooks (R10-④b), row-geometry form (the grid resolves
  /// row deltas to layers); null hides the block body handles.
  final TimelineBlockMoveHandleCallbacks? blockMove;
  final PropertyLaneEditCallbacks? laneEdit;

  /// The session's edit-drag preview channel: a drag step rebuilds ONLY the
  /// dragged layer's row (through its gate), never this body.
  final ValueListenable<TimelineDragPreview?>? dragPreview;

  @override
  State<TimelineFrameRowsScrollBody> createState() =>
      _TimelineFrameRowsScrollBodyState();
}

/// The data snapshot a memoized row was built from. The CONTENT-deciding
/// callbacks (exposure state, frame names) join the key by equality —
/// session method tearoffs compare equal across host rebuilds, so the
/// memo still hits in production while injected test closures invalidate
/// it. Behavior-only callbacks (select/activate hooks) are deliberately
/// NOT part of the key: every timeline host callback closes over the
/// stable session only, so a cached row's captured hooks stay
/// behaviorally identical even when their object identities churn.
typedef _RowMemoInputs = ({
  Layer layer,
  bool active,
  int playbackFrameCount,
  int frameStartIndex,
  int frameEndIndexExclusive,
  double leadingFrameSpacerWidth,
  double trailingFrameSpacerWidth,
  TimelineGridMetrics metrics,
  int projectFps,
  TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer,
  String? Function(Layer layer, int frameIndex)? frameNameForLayer,
  bool hasCommaDrag,
  bool hasBlockMove,
  bool hasActivateCell,
  ValueListenable<TimelineDragPreview?>? dragPreview,
});

class _RowMemoEntry {
  const _RowMemoEntry({required this.inputs, required this.widget});

  final _RowMemoInputs inputs;
  final Widget widget;
}

class _TimelineFrameRowsScrollBodyState
    extends State<TimelineFrameRowsScrollBody> {
  /// Identity-gated row memo (the timesheet-document memo, per row): on a
  /// commit-time rebuild the untouched layers come back as the SAME Layer
  /// instances from the repository, so their rows reuse the cached widget
  /// INSTANCE and Flutter skips their whole subtree rebuild. Only kinds
  /// whose row visuals derive purely from the Layer value are memoized —
  /// camera rows read the active cut's camera track, SE rows resolve
  /// waveform peaks that load asynchronously, and lane rows are few.
  final Map<Object, _RowMemoEntry> _rowMemo = {};

  bool _rowIsMemoizable(TimelineDisplayRow row) {
    if (row.isLane) {
      return false;
    }
    switch (row.layer.kind) {
      case LayerKind.animation:
      case LayerKind.storyboard:
      case LayerKind.art:
        return true;
      case LayerKind.se:
      case LayerKind.instruction:
      case LayerKind.camera:
        return false;
    }
  }

  bool _inputsMatch(_RowMemoInputs a, _RowMemoInputs b) {
    return identical(a.layer, b.layer) &&
        a.active == b.active &&
        a.playbackFrameCount == b.playbackFrameCount &&
        a.frameStartIndex == b.frameStartIndex &&
        a.frameEndIndexExclusive == b.frameEndIndexExclusive &&
        a.leadingFrameSpacerWidth == b.leadingFrameSpacerWidth &&
        a.trailingFrameSpacerWidth == b.trailingFrameSpacerWidth &&
        a.metrics == b.metrics &&
        a.projectFps == b.projectFps &&
        a.exposureStateForLayer == b.exposureStateForLayer &&
        a.frameNameForLayer == b.frameNameForLayer &&
        a.hasCommaDrag == b.hasCommaDrag &&
        a.hasBlockMove == b.hasBlockMove &&
        a.hasActivateCell == b.hasActivateCell &&
        identical(a.dragPreview, b.dragPreview);
  }

  Widget _buildCellsRow(Layer layer, {required Layer baseLayer}) {
    return TimelineFrameCellsRow(
      layer: layer,
      baseLayer: baseLayer,
      active: layer.id == widget.activeLayerId,
      playbackFrameCount: widget.playbackFrameCount,
      frameStartIndex: widget.frameStartIndex,
      frameEndIndexExclusive: widget.frameEndIndexExclusive,
      leadingFrameSpacerWidth: widget.leadingFrameSpacerWidth,
      trailingFrameSpacerWidth: widget.trailingFrameSpacerWidth,
      metrics: widget.metrics,
      exposureStateForLayer: widget.exposureStateForLayer,
      frameNameForLayer: widget.frameNameForLayer,
      onSelectLayer: widget.onSelectLayer,
      onSelectFrame: widget.onSelectFrame,
      onActivateCell: widget.onActivateCell,
      instructionDefById: widget.instructionDefById,
      audioPeaksFor: widget.audioPeaksFor,
      projectFps: widget.projectFps,
      onRemoveAudioClip: widget.onRemoveAudioClip,
      onDropMediaAsset: widget.onDropMediaAsset,
      commaDrag: widget.commaDrag,
      blockMove: widget.blockMove,
    );
  }

  Widget _buildLaneRow(TimelineDisplayRow row, Layer layer) {
    return laneIsSeAudio(row.lane!)
        ? SeAudioLaneFrameRow(
            layer: layer,
            frameStartIndex: widget.frameStartIndex,
            frameEndIndexExclusive: widget.frameEndIndexExclusive,
            leadingFrameSpacerWidth: widget.leadingFrameSpacerWidth,
            trailingFrameSpacerWidth: widget.trailingFrameSpacerWidth,
            metrics: widget.metrics,
            fps: widget.projectFps,
            audioPeaksFor: widget.audioPeaksFor,
            onSetClipOffset: widget.onSetAudioClipOffset == null
                ? null
                : (clipIndex, offsetFrames) => widget.onSetAudioClipOffset!(
                    layer.id,
                    clipIndex,
                    offsetFrames,
                  ),
            offsetDrag: widget.audioOffsetDrag,
            onSetClipFades: widget.onSetAudioClipFades == null
                ? null
                : (clipIndex, fadeIn, fadeOut) => widget.onSetAudioClipFades!(
                    layer.id,
                    clipIndex,
                    fadeIn,
                    fadeOut,
                  ),
            onSetClipGain: widget.onSetAudioClipGain == null
                ? null
                : (clipIndex, gain) =>
                      widget.onSetAudioClipGain!(layer.id, clipIndex, gain),
          )
        : TimelineLaneFrameRow(
            layer: layer,
            lane: row.lane!,
            frameStartIndex: widget.frameStartIndex,
            frameEndIndexExclusive: widget.frameEndIndexExclusive,
            leadingFrameSpacerWidth: widget.leadingFrameSpacerWidth,
            trailingFrameSpacerWidth: widget.trailingFrameSpacerWidth,
            metrics: widget.metrics,
            laneEdit: widget.laneEdit,
          );
  }

  Widget _buildRow(TimelineDisplayRow row) {
    final rowKey = ValueKey<String>(
      'timeline-row-${row.layer.id}-${row.lane?.laneId ?? 'cells'}',
    );

    // RepaintBoundary per row: one row's repaint (ink, hover, drags) never
    // re-rasterizes its neighbours, and the cursor layer above repaints
    // without touching the row layers at all. The gate inside makes an
    // edge-drag step rebuild exactly this row when it is the drag target.
    Widget buildGated() => RepaintBoundary(
      key: rowKey,
      child: TimelineDragPreviewRowGate(
        dragPreview: widget.dragPreview,
        layer: row.layer,
        rowBuilder: (context, layer) => row.isLane
            ? _buildLaneRow(row, layer)
            : _buildCellsRow(layer, baseLayer: row.layer),
      ),
    );

    if (!_rowIsMemoizable(row)) {
      return buildGated();
    }

    final inputs = (
      layer: row.layer,
      active: row.layer.id == widget.activeLayerId,
      playbackFrameCount: widget.playbackFrameCount,
      frameStartIndex: widget.frameStartIndex,
      frameEndIndexExclusive: widget.frameEndIndexExclusive,
      leadingFrameSpacerWidth: widget.leadingFrameSpacerWidth,
      trailingFrameSpacerWidth: widget.trailingFrameSpacerWidth,
      metrics: widget.metrics,
      projectFps: widget.projectFps,
      exposureStateForLayer: widget.exposureStateForLayer,
      frameNameForLayer: widget.frameNameForLayer,
      hasCommaDrag: widget.commaDrag != null,
      hasBlockMove: widget.blockMove != null,
      hasActivateCell: widget.onActivateCell != null,
      dragPreview: widget.dragPreview,
    );
    final cached = _rowMemo[rowKey.value];
    if (cached != null && _inputsMatch(cached.inputs, inputs)) {
      return cached.widget;
    }
    final built = buildGated();
    _rowMemo[rowKey.value] = _RowMemoEntry(inputs: inputs, widget: built);
    return built;
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (widget.leadingLayerSpacerHeight > 0)
        SizedBox(
          key: const ValueKey<String>('timeline-leading-layer-spacer'),
          height: widget.leadingLayerSpacerHeight,
        ),
      for (final row in widget.rows) _buildRow(row),
      if (widget.trailingLayerSpacerHeight > 0)
        SizedBox(
          key: const ValueKey<String>('timeline-trailing-layer-spacer'),
          height: widget.trailingLayerSpacerHeight,
        ),
      if (widget.rows.isEmpty)
        SizedBox(
          width: widget.totalFrameContentWidth,
          height: widget.metrics.layerRowHeight,
        ),
    ];

    // Bound the memo to the rows built this pass (scrolled-out rows just
    // rebuild when they come back).
    final liveKeys = <Object>{
      for (final row in widget.rows)
        'timeline-row-${row.layer.id}-${row.lane?.laneId ?? 'cells'}',
    };
    _rowMemo.removeWhere((key, _) => !liveKeys.contains(key));

    return KeyedSubtree(
      key: const ValueKey<String>('timeline-frame-rows-scroll-body'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
