import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/camera_instruction.dart';
import '../../models/layer.dart';
import '../../services/audio/audio_peaks_extractor.dart';
import '../../models/layer_id.dart';
import '../../models/layer_mark.dart';
import 'layer_timeline_display_adapter.dart';
import 'layer_timeline_grid.dart';
import 'property_lane_model.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_range_policy.dart' show timelineSecondsLabel;
import 'timeline_grid_metrics.dart';
import 'timeline_orientation.dart';
import 'timeline_section_policy.dart';
import 'xsheet_timeline_grid.dart';

class TimelinePanel extends StatefulWidget {
  const TimelinePanel({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.frameCursor,
    this.cacheProgress,
    required this.playbackFrameCount,
    required this.exposureStateForLayer,
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
    this.onActivateCell,
    this.instructionDefById,
    this.audioPeaksFor,
    this.onRemoveAudioClip,
    this.onDropMediaAsset,
    this.onSetAudioClipOffset,
    this.onSetAudioClipFades,
    this.onSetAudioClipGain,
    required this.onAddLayer,
    required this.onToggleLayerVisibility,
    required this.onLayerOpacityChanged,
    required this.onToggleLayerTimesheet,
    required this.onLayerMarkSelected,
    this.layerFxEnabledOf,
    this.onToggleLayerFx,
    this.onToggleLayerMuted,
    this.commaDrag,
    this.isFrameCached,
    required this.orientation,
    required this.onOrientationChanged,
    this.timelineActionToolbar,
    this.pixelsPerFrame = TimelinePanel.defaultPixelsPerFrame,
    this.onPixelsPerFrameChanged,
    this.showSeconds = false,
    this.onShowSecondsChanged,
    this.projectFps = 24,
    this.expandedLaneLayerIds = const {},
    this.onToggleLayerLanes,
    this.lanesForLayer,
    this.laneEdit,
    this.hiddenSections = const {},
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;

  /// The frame cursor (editing playhead / playback position). Only the
  /// cursor-driven widgets subscribe — a tick never rebuilds the panel or
  /// its grids (the playback-performance architecture, both orientations).
  final ValueListenable<int> frameCursor;

  /// Repaints the rulers' cached-range green strip as frames warm.
  final Listenable? cacheProgress;

  final int playbackFrameCount;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  /// Double-tap cell editor hook (SE label dialog), shared by both
  /// orientations.
  final void Function(LayerId layerId, int frameIndex)? onActivateCell;

  /// Resolves instruction ids to defs for CAM row chips.
  final CameraInstructionDef? Function(String instructionId)?
  instructionDefById;

  /// Waveform peaks for SE rows' audio clips + the removal hook (both
  /// orientations; frames↔seconds via [projectFps]).
  final AudioPeaks? Function(String filePath)? audioPeaksFor;
  final void Function(LayerId layerId, int clipIndex)? onRemoveAudioClip;

  /// Links a media-browser asset to an SE block (drag-drop), both
  /// orientations.
  final void Function(LayerId layerId, int blockStartFrame, String path)?
  onDropMediaAsset;

  /// Commits an audio-lane slide (the clip's offset trim), both
  /// orientations.
  final void Function(LayerId layerId, int clipIndex, int offsetFrames)?
  onSetAudioClipOffset;

  /// Commits an audio-lane fade-handle drag, both orientations.
  final void Function(
    LayerId layerId,
    int clipIndex,
    int fadeInFrames,
    int fadeOutFrames,
  )?
  onSetAudioClipFades;

  /// Commits the audio-lane gain dialog, both orientations.
  final void Function(LayerId layerId, int clipIndex, double gain)?
  onSetAudioClipGain;

  final VoidCallback onAddLayer;
  final ValueChanged<LayerId> onToggleLayerVisibility;
  final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;
  final ValueChanged<LayerId> onToggleLayerTimesheet;
  final void Function(LayerId layerId, LayerMark mark) onLayerMarkSelected;

  /// The AE-style layer fx switch (session view state), both orientations;
  /// null hides it.
  final bool Function(LayerId layerId)? layerFxEnabledOf;
  final ValueChanged<LayerId>? onToggleLayerFx;

  /// SE rows' speaker button (mute), both orientations; null hides it.
  final ValueChanged<LayerId>? onToggleLayerMuted;

  /// Comma-drag hooks for the block edge grips, shared by both
  /// orientations; null hides the grips.
  final TimelineCommaDragCallbacks? commaDrag;

  /// Cached-range resolver for the green strip (horizontal ruler and the
  /// X-sheet frame rail).
  final bool Function(int frameIndex)? isFrameCached;

  final TimelineOrientation orientation;
  final ValueChanged<TimelineOrientation> onOrientationChanged;
  final Widget? timelineActionToolbar;

  /// Frame-axis zoom, DaVinci/AE-style continuous slider value in pixels
  /// per frame; the shared range covers the storyboard's overview zooms
  /// and the timeline's classic cell width alike. The X-sheet's frame row
  /// height scales proportionally so its classic geometry sits at the
  /// same default.
  static const double minPixelsPerFrame = 4;
  static const double maxPixelsPerFrame = 96;
  static const double defaultPixelsPerFrame = 48;

  /// The ACTIVE view's zoom (the host routes it to the timeline or the
  /// storyboard value depending on the shown mode).
  final double pixelsPerFrame;
  final ValueChanged<double>? onPixelsPerFrameChanged;

  /// Frames↔seconds display toggle, shared by the timeline counter and the
  /// storyboard cut totals (conte-sheet `s+ff` notation).
  final bool showSeconds;
  final ValueChanged<bool>? onShowSecondsChanged;
  final int projectFps;

  /// AE-style property lanes (twirl-down rows under a layer): expansion
  /// state, toggle and the generic lane provider.
  final Set<LayerId> expandedLaneLayerIds;
  final ValueChanged<LayerId>? onToggleLayerLanes;
  final List<PropertyLaneRow> Function(Layer layer)? lanesForLayer;
  final PropertyLaneEditCallbacks? laneEdit;

  /// SE/camera sections folded to stub rows (columns in the X-sheet), and
  /// the gutter/header toggle. Shared by both orientations.
  final Set<TimelineSection> hiddenSections;

  @override
  State<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<TimelinePanel> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontalLayers = horizontalLayerDisplayOrder(widget.layers);
    final nextOrientation = widget.orientation == TimelineOrientation.horizontal
        ? TimelineOrientation.vertical
        : TimelineOrientation.horizontal;
    final showToolbar = widget.timelineActionToolbar != null;

    // The slider value is the horizontal cell width; the X-sheet's frame
    // row height scales proportionally (36 at the classic 48).
    final horizontalMetrics = TimelineGridMetrics.defaults.copyWith(
      frameCellWidth: widget.pixelsPerFrame,
    );
    final xsheetMetrics = XSheetTimelineGrid.defaultMetrics.copyWith(
      frameCellWidth:
          widget.pixelsPerFrame *
          (XSheetTimelineGrid.defaultMetrics.frameCellWidth /
              TimelineGridMetrics.defaults.frameCellWidth),
    );

    return Material(
      color: colorScheme.surfaceContainerHighest,
      // Height comes from the hosting panel region (the tab group).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
            child: Row(
              children: [
                // The counter subscribes to the cursor itself: a tick
                // rebuilds this one Text, nothing else.
                ValueListenableBuilder<int>(
                  valueListenable: widget.frameCursor,
                  builder: (context, cursorFrame, _) => Text(
                    widget.showSeconds
                        ? timelineSecondsLabel(
                            cursorFrame + 1,
                            widget.projectFps,
                          )
                        : '${cursorFrame + 1}',
                    key: const ValueKey<String>(
                      'timeline-current-frame-counter',
                    ),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const ValueKey<String>(
                    'timeline-time-display-toggle-button',
                  ),
                  tooltip: widget.showSeconds ? 'Show Frames' : 'Show Seconds',
                  onPressed: widget.onShowSecondsChanged == null
                      ? null
                      : () => widget.onShowSecondsChanged!(!widget.showSeconds),
                  icon: Icon(
                    widget.showSeconds ? Icons.timer : Icons.timer_outlined,
                    size: 18,
                  ),
                ),
                // The frame-axis zoom slider is shared by every mode
                // (timeline, X-sheet AND storyboard).
                Icon(
                  Icons.zoom_out,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                SizedBox(
                  width: 140,
                  child: Slider(
                    key: const ValueKey<String>('timeline-zoom-slider'),
                    min: TimelinePanel.minPixelsPerFrame,
                    max: TimelinePanel.maxPixelsPerFrame,
                    value: widget.pixelsPerFrame.clamp(
                      TimelinePanel.minPixelsPerFrame,
                      TimelinePanel.maxPixelsPerFrame,
                    ),
                    onChanged: widget.onPixelsPerFrameChanged,
                  ),
                ),
                Icon(
                  Icons.zoom_in,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey<String>(
                    'timeline-toolbar-add-layer-button',
                  ),
                  tooltip: 'Add layer',
                  onPressed: widget.onAddLayer,
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  key: const ValueKey<String>(
                    'timeline-orientation-toggle-button',
                  ),
                  tooltip: widget.orientation == TimelineOrientation.horizontal
                      ? 'Show X-sheet'
                      : 'Show timeline',
                  onPressed: () => widget.onOrientationChanged(nextOrientation),
                  icon: const Icon(Icons.swap_horiz),
                ),
              ],
            ),
          ),
          if (showToolbar)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: widget.timelineActionToolbar,
            ),
          Expanded(
            child: widget.orientation == TimelineOrientation.horizontal
                ? LayerTimelineGrid(
                    layers: horizontalLayers,
                    activeLayerId: widget.activeLayerId,
                    frameCursor: widget.frameCursor,
                    cacheProgress: widget.cacheProgress,
                    playbackFrameCount: widget.playbackFrameCount,
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
                    onSetAudioClipOffset: widget.onSetAudioClipOffset,
                    onSetAudioClipFades: widget.onSetAudioClipFades,
                    onSetAudioClipGain: widget.onSetAudioClipGain,
                    onAddLayer: widget.onAddLayer,
                    onToggleLayerMuted: widget.onToggleLayerMuted,
                    onToggleLayerVisibility: widget.onToggleLayerVisibility,
                    onLayerOpacityChanged: widget.onLayerOpacityChanged,
                    onToggleLayerTimesheet: widget.onToggleLayerTimesheet,
                    onLayerMarkSelected: widget.onLayerMarkSelected,
                    layerFxEnabledOf: widget.layerFxEnabledOf,
                    onToggleLayerFx: widget.onToggleLayerFx,
                    commaDrag: widget.commaDrag,
                    isFrameCached: widget.isFrameCached,
                    metrics: horizontalMetrics,
                    expandedLaneLayerIds: widget.expandedLaneLayerIds,
                    onToggleLayerLanes: widget.onToggleLayerLanes,
                    lanesForLayer: widget.lanesForLayer,
                    laneEdit: widget.laneEdit,
                    hiddenSections: widget.hiddenSections,
                  )
                : XSheetTimelineGrid(
                    layers: xsheetLayerDisplayOrder(widget.layers),
                    activeLayerId: widget.activeLayerId,
                    frameCursor: widget.frameCursor,
                    cacheProgress: widget.cacheProgress,
                    frameCount: widget.playbackFrameCount,
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
                    onSetAudioClipOffset: widget.onSetAudioClipOffset,
                    onSetAudioClipFades: widget.onSetAudioClipFades,
                    onSetAudioClipGain: widget.onSetAudioClipGain,
                    onAddLayer: widget.onAddLayer,
                    onToggleLayerMuted: widget.onToggleLayerMuted,
                    onToggleLayerVisibility: widget.onToggleLayerVisibility,
                    onLayerOpacityChanged: widget.onLayerOpacityChanged,
                    onToggleLayerTimesheet: widget.onToggleLayerTimesheet,
                    onLayerMarkSelected: widget.onLayerMarkSelected,
                    layerFxEnabledOf: widget.layerFxEnabledOf,
                    onToggleLayerFx: widget.onToggleLayerFx,
                    commaDrag: widget.commaDrag,
                    isFrameCached: widget.isFrameCached,
                    metrics: xsheetMetrics,
                    expandedLaneLayerIds: widget.expandedLaneLayerIds,
                    onToggleLayerLanes: widget.onToggleLayerLanes,
                    lanesForLayer: widget.lanesForLayer,
                    laneEdit: widget.laneEdit,
                    hiddenSections: widget.hiddenSections,
                  ),
          ),
        ],
      ),
    );
  }
}
