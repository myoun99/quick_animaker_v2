import 'package:flutter/material.dart';

import '../../models/camera_instruction.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../services/audio/audio_peaks_extractor.dart';
import 'property_lane_model.dart';
import 'se_audio_lane.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_cells_row.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_lane_rows.dart';
import 'timeline_section_policy.dart';

class TimelineFrameRowsScrollBody extends StatelessWidget {
  const TimelineFrameRowsScrollBody({
    super.key,
    required this.layers,
    required this.rows,
    required this.activeLayerId,
    required this.playbackFrameCount,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.leadingFrameSpacerWidth,
    required this.trailingFrameSpacerWidth,
    required this.totalFrameContentWidth,
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
    this.commaDrag,
    this.laneEdit,
  });

  /// Display layers (section-divider positions key off layer indexes).
  final List<Layer> layers;

  /// Display rows: layer rows interleaved with expanded property lanes.
  final List<TimelineDisplayRow> rows;
  final LayerId? activeLayerId;
  final int playbackFrameCount;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final double totalFrameContentWidth;
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

  final TimelineCommaDragCallbacks? commaDrag;
  final PropertyLaneEditCallbacks? laneEdit;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey<String>('timeline-frame-rows-scroll-body'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RepaintBoundary per row: one row's repaint (ink, hover, drags)
          // never re-rasterizes its neighbours, and the cursor layer above
          // repaints without touching the row layers at all.
          for (final row in rows)
            RepaintBoundary(
              child: row.isLane
                  ? (laneIsSeAudio(row.lane!)
                        ? SeAudioLaneFrameRow(
                            layer: row.layer,
                            frameStartIndex: frameStartIndex,
                            frameEndIndexExclusive: frameEndIndexExclusive,
                            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
                            trailingFrameSpacerWidth: trailingFrameSpacerWidth,
                            metrics: metrics,
                            fps: projectFps,
                            audioPeaksFor: audioPeaksFor,
                            onSetClipOffset: onSetAudioClipOffset == null
                                ? null
                                : (clipIndex, offsetFrames) =>
                                      onSetAudioClipOffset!(
                                        row.layer.id,
                                        clipIndex,
                                        offsetFrames,
                                      ),
                          )
                        : TimelineLaneFrameRow(
                            layer: row.layer,
                            lane: row.lane!,
                            frameStartIndex: frameStartIndex,
                            frameEndIndexExclusive: frameEndIndexExclusive,
                            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
                            trailingFrameSpacerWidth: trailingFrameSpacerWidth,
                            metrics: metrics,
                            laneEdit: laneEdit,
                          ))
                  : TimelineFrameCellsRow(
                      layer: row.layer,
                      active: row.layer.id == activeLayerId,
                      sectionStart: timelineSectionStartsAt(
                        layers,
                        row.layerIndex,
                      ),
                      playbackFrameCount: playbackFrameCount,
                      frameStartIndex: frameStartIndex,
                      frameEndIndexExclusive: frameEndIndexExclusive,
                      leadingFrameSpacerWidth: leadingFrameSpacerWidth,
                      trailingFrameSpacerWidth: trailingFrameSpacerWidth,
                      metrics: metrics,
                      exposureStateForLayer: exposureStateForLayer,
                      frameNameForLayer: frameNameForLayer,
                      onSelectLayer: onSelectLayer,
                      onSelectFrame: onSelectFrame,
                      onActivateCell: onActivateCell,
                      instructionDefById: instructionDefById,
                      audioPeaksFor: audioPeaksFor,
                      projectFps: projectFps,
                      onRemoveAudioClip: onRemoveAudioClip,
                      onDropMediaAsset: onDropMediaAsset,
                      commaDrag: commaDrag,
                    ),
            ),
          if (rows.isEmpty)
            SizedBox(
              width: totalFrameContentWidth,
              height: metrics.layerRowHeight,
            ),
        ],
      ),
    );
  }
}
