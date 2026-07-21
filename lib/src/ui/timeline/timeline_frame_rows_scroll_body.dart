import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/audio_clip.dart' show AudioFadeCurve, AudioVolumeKey;
import '../../models/camera_instruction.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../../services/audio/audio_peaks_extractor.dart';
import 'property_lane_model.dart';
import 'se_audio_lane.dart';
import 'timeline_frame_range_gesture.dart';
import 'timeline_run_end_handles.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_drag_preview.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_folder_aggregate_row.dart';
import 'timeline_frame_cells_row.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_lane_rows.dart';

import '../../models/project_frame_rate.dart';

/// See [TimelineFrameRowsScrollBody.memoAux].
class TimelineRowMemoAux {
  const TimelineRowMemoAux({this.cameraTrack, this.instructionDefs});

  /// The active cut's camera track object (immutable — a key edit is a
  /// new instance).
  final Object? cameraTrack;

  /// The camera-instruction registry object.
  final Object? instructionDefs;
}

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
    this.projectFrameRate = ProjectFrameRate.fps24,
    this.onRemoveAudioClip,
    this.onDropMediaAsset,
    this.onSetAudioClipOffset,
    this.audioOffsetDrag,
    this.onSetAudioClipFades,
    this.onSetAudioClipGain,
    this.onSetAudioClipFadeCurve,
    this.onSetAudioClipEnvelope,
    this.commaDrag,
    this.rangeGesture,
    this.laneRange,
    this.runEdit,
    this.laneEdit,
    this.dragPreview,
    this.seSpillInLayerIds = const {},
    this.windowBucket,
    this.viewportMainExtent = 0,
    this.memoAux = const TimelineRowMemoAux(),
  });

  /// Identity tokens for the sparse rows' EXTERNAL inputs (UI-R20 #4):
  /// the camera row reads the cut's camera track and instruction rows
  /// read the instruction registry — both outside the Layer value, so
  /// their identities join the memo key here. Hosts pass the live
  /// objects; a key change is exactly an edit.
  final TimelineRowMemoAux memoAux;

  /// PRO-TIMELINE scrolling (UI-R15→R16): with these set the drawing rows
  /// build once for the full bounds (their painters window themselves off
  /// the quantized bucket — repaint per span crossing, pure translation
  /// between) and the sparse rows re-window under the same bucket — a
  /// scroll rebuilds nothing here.
  final ValueListenable<int>? windowBucket;
  final double viewportMainExtent;

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
  final ProjectFrameRate projectFrameRate;
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

  /// Commits the audio-lane fade-curve toggle (AUDIO-PRO R1).
  final void Function(LayerId layerId, int clipIndex, AudioFadeCurve curve)?
  onSetAudioClipFadeCurve;

  /// Commits the audio-lane volume-envelope dialog (AUDIO-PRO R1).
  final void Function(
    LayerId layerId,
    int clipIndex,
    List<AudioVolumeKey> keys,
  )?
  onSetAudioClipEnvelope;

  final TimelineCommaDragCallbacks? commaDrag;

  /// The range select/move gesture bundle (UI-R8 — the block-body move
  /// handle's successor); null keeps rows display-only.
  final TimelineRangeGestureCallbacks? rangeGesture;

  /// The LANE selection domain's gesture bundle (UI-R23 #3 part 2); null
  /// keeps the lane bands display-only.
  final TimelineLaneRangeCallbacks? laneRange;

  /// The run-edge [+]/[↻] handle hooks (UI-R8); null hides the handles.
  final TimelineRunEditCallbacks? runEdit;
  final PropertyLaneEditCallbacks? laneEdit;

  /// The session's edit-drag preview channel: a drag step rebuilds ONLY the
  /// dragged layer's row (through its gate), never this body.
  final ValueListenable<TimelineDragPreview?>? dragPreview;

  /// Track-SE rows whose display clone starts with a spill-in block
  /// (UI-R7 #6: `~` at the cut start, start grip stands down).
  final Set<LayerId> seSpillInLayerIds;

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
  ProjectFrameRate projectFrameRate,
  TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer,
  String? Function(Layer layer, int frameIndex)? frameNameForLayer,
  bool hasCommaDrag,
  bool hasRangeGesture,
  bool hasActivateCell,
  ValueListenable<TimelineDragPreview?>? dragPreview,
  // The sparse rows' EXTERNAL inputs (UI-R20 #4): identity tokens for
  // the camera track / instruction registry, and the SE spill-in flag.
  Object? auxiliaryIdentity,
  bool seSpillsIn,
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

  /// Folder rows key off their FOLDER id — the representative layer they
  /// carry would collide with its own layer row otherwise.
  String _rowKeySuffix(TimelineDisplayRow row) => row.folder != null
      ? 'folder-${row.folder!.id}'
      : row.lane?.laneId ?? 'cells';

  bool _rowIsMemoizable(TimelineDisplayRow row) {
    // Every non-lane row memoizes now (UI-R20 #4): the churny inputs the
    // sparse kinds depended on joined the memo token — the camera track
    // and the instruction registry ride [TimelineRowMemoAux] identities,
    // SE spill-in rides a per-layer flag, and the SE/camera display
    // clones themselves are identity-cached upstream. The audio WAVEFORM
    // stays safe because it lives on the (unmemoized) lane rows.
    // Folder rows stay unmemoized too: their aggregate runs churn
    // identity per build and the painter is a handful of rects.
    return !row.isLane && !row.isFolder;
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
        a.projectFrameRate == b.projectFrameRate &&
        a.exposureStateForLayer == b.exposureStateForLayer &&
        a.frameNameForLayer == b.frameNameForLayer &&
        a.hasCommaDrag == b.hasCommaDrag &&
        a.hasRangeGesture == b.hasRangeGesture &&
        a.hasActivateCell == b.hasActivateCell &&
        identical(a.dragPreview, b.dragPreview) &&
        identical(a.auxiliaryIdentity, b.auxiliaryIdentity) &&
        a.seSpillsIn == b.seSpillsIn;
  }

  /// The row kind's external-input identity for the memo token.
  Object? _auxiliaryIdentityFor(Layer layer) {
    return switch (layer.kind) {
      LayerKind.camera => widget.memoAux.cameraTrack,
      LayerKind.instruction => widget.memoAux.instructionDefs,
      _ => null,
    };
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
      projectFrameRate: widget.projectFrameRate,
      onRemoveAudioClip: widget.onRemoveAudioClip,
      onDropMediaAsset: widget.onDropMediaAsset,
      commaDrag: widget.commaDrag,
      rangeGesture: widget.rangeGesture,
      runEdit: widget.runEdit,
      seSpillsIn: widget.seSpillInLayerIds.contains(layer.id),
      windowBucket: widget.windowBucket,
      viewportMainExtent: widget.viewportMainExtent,
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
            frameRate: widget.projectFrameRate,
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
            onSetClipFadeCurve: widget.onSetAudioClipFadeCurve == null
                ? null
                : (clipIndex, curve) => widget.onSetAudioClipFadeCurve!(
                    layer.id,
                    clipIndex,
                    curve,
                  ),
            onSetClipEnvelope: widget.onSetAudioClipEnvelope == null
                ? null
                : (clipIndex, keys) => widget.onSetAudioClipEnvelope!(
                    layer.id,
                    clipIndex,
                    keys,
                  ),
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
            // The LANE selection domain (UI-R23 #3 part 2) — layer
            // transform lanes only; the camera's atomic keyframes stand
            // down in v1.
            laneRange: layer.kind == LayerKind.camera
                ? null
                : widget.laneRange,
          );
  }

  Widget _buildRow(TimelineDisplayRow row) {
    final rowKey = ValueKey<String>(
      'timeline-row-${row.layer.id}-${_rowKeySuffix(row)}',
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
        rowBuilder: (context, layer) => row.isFolder
            ? TimelineFolderAggregateRow(
                aggregateRuns: row.aggregateRuns,
                frameStartIndex: widget.frameStartIndex,
                frameEndIndexExclusive: widget.frameEndIndexExclusive,
                leadingFrameSpacerWidth: widget.leadingFrameSpacerWidth,
                trailingFrameSpacerWidth: widget.trailingFrameSpacerWidth,
                metrics: widget.metrics,
              )
            : row.isLane
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
      projectFrameRate: widget.projectFrameRate,
      exposureStateForLayer: widget.exposureStateForLayer,
      frameNameForLayer: widget.frameNameForLayer,
      hasCommaDrag: widget.commaDrag != null,
      hasRangeGesture: widget.rangeGesture != null,
      hasActivateCell: widget.onActivateCell != null,
      dragPreview: widget.dragPreview,
      auxiliaryIdentity: _auxiliaryIdentityFor(row.layer),
      seSpillsIn: widget.seSpillInLayerIds.contains(row.layer.id),
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
        'timeline-row-${row.layer.id}-${_rowKeySuffix(row)}',
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
