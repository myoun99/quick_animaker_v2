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
import 'se_audio_lane.dart' show AudioOffsetDragCallbacks;
import 'timeline_cell_exposure_state.dart';
import 'timeline_drag_preview.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_range_gesture.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_run_end_handles.dart';
import 'timeline_layer_controls_header.dart' show LayerLegendCallbacks;
import 'timeline_row_filter.dart';
import 'timeline_section_bracket_rail.dart' show TimelineSectionRailCallbacks;
import 'timeline_view_cluster.dart';
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
    this.onScrubFrame,
    this.onScrubEnd,
    this.onActivateCell,
    this.instructionDefById,
    this.audioPeaksFor,
    this.onRemoveAudioClip,
    this.onDropMediaAsset,
    this.onSetAudioClipOffset,
    this.audioOffsetDrag,
    this.onSetAudioClipFades,
    this.onSetAudioClipGain,
    required this.onAddLayer,
    required this.onToggleLayerVisibility,
    required this.onLayerOpacityChanged,
    this.onLayerOpacityChangeEnd,
    required this.onToggleLayerTimesheet,
    this.onToggleLayerFillReference,
    required this.onLayerMarkSelected,
    this.layerFxEnabledOf,
    this.onToggleLayerFx,
    this.onToggleLayerMuted,
    this.commaDrag,
    this.rangeHooks,
    this.runEdit,
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
    this.onToggleLaneGroup,
    this.hiddenSections = const {},
    this.onToggleSection,
    this.legend,
    this.sectionRail,
    this.rowFilter = TimelineRowFilter.none,
    this.onSetRowFilter,
    this.visibilitySoloEnabled = false,
    this.opacityDragPreview,
    this.masterOpacityValue = 1.0,
    this.dragPreview,
    this.seSpillInLayerIds = const {},
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;

  /// The session's edit-drag preview channel (comma/trim drags), consumed
  /// by both grids' row gates and cursor overlays.
  final ValueListenable<TimelineDragPreview?>? dragPreview;

  /// Track-SE rows whose display clone starts with a spill-in block
  /// (UI-R7 #6: `~` at the cut start, start grip stands down).
  final Set<LayerId> seSpillInLayerIds;

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

  /// Ruler-scrub path (both orientations): per-move frames go to
  /// [onScrubFrame] (cursor-only, no commit) and the release fires
  /// [onScrubEnd] to commit once. Null falls back to [onSelectFrame] per
  /// move (immediate-commit behavior).
  final ValueChanged<int>? onScrubFrame;
  final VoidCallback? onScrubEnd;

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

  /// Live drag session for the slide (repo-direct preview + one undo),
  /// both orientations.
  final AudioOffsetDragCallbacks? audioOffsetDrag;

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

  /// Commit-on-release hook (R4 #4); null keeps per-move writes.
  final void Function(LayerId layerId, double opacity)? onLayerOpacityChangeEnd;
  final ValueChanged<LayerId> onToggleLayerTimesheet;

  /// Drawing rows' fill-reference toggle (R20-C2); null hides it.
  final ValueChanged<LayerId>? onToggleLayerFillReference;
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

  /// The frame-range select/move hooks (UI-R8), shared by both
  /// orientations; null keeps rows display-only.
  final TimelineFrameRangeHooks? rangeHooks;

  /// The run-edge [+]/[↻] handle hooks (UI-R8), both orientations; null
  /// hides the handles.
  final TimelineRunEditCallbacks? runEdit;

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
  // 48 → 24 (R-toolbar slim round): the zoom slider's 100% now reads the
  // CSP/TVPaint-density default.
  static const double defaultPixelsPerFrame = 24;

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

  /// Group headers: tapping twirls the group's member lanes (AE collapse),
  /// both orientations.
  final void Function(Layer layer, PropertyLaneRow lane)? onToggleLaneGroup;

  /// SE/camera sections folded to stub rows (columns in the X-sheet), and
  /// the gutter/header toggle. Shared by both orientations.
  final Set<TimelineSection> hiddenSections;

  /// Folds/unfolds a hideable section (legend corner + bracket chevrons).
  final ValueChanged<TimelineSection>? onToggleSection;

  /// The rail legend's bulk commands (horizontal timeline only).
  final LayerLegendCallbacks? legend;

  /// The section brackets' flyout commands (horizontal timeline only).
  final TimelineSectionRailCallbacks? sectionRail;

  /// The rail's row filter and its editor (R2); shared by both orientations.
  final TimelineRowFilter rowFilter;
  final ValueChanged<TimelineRowFilter>? onSetRowFilter;

  /// Whether the visibility solo mode is engaged (legend eye state color).
  final bool visibilitySoloEnabled;

  /// The session's live opacity-drag preview + the master bar's resting
  /// value (UI-R6 #2).
  final ValueListenable<({Set<LayerId> layerIds, double opacity})?>?
  opacityDragPreview;
  final double masterOpacityValue;

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
          // ONE command-bar row (R-toolbar round): the host's transport +
          // action toolbar on the left, the shared view cluster pinned
          // right. The old separate top row is gone.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(
              children: [
                if (showToolbar)
                  Expanded(child: widget.timelineActionToolbar!)
                else
                  const Spacer(),
                const SizedBox(width: 8),
                TimelineViewCluster(
                  frameCursor: widget.frameCursor,
                  projectFps: widget.projectFps,
                  showSeconds: widget.showSeconds,
                  onShowSecondsChanged: widget.onShowSecondsChanged,
                  pixelsPerFrame: widget.pixelsPerFrame,
                  onPixelsPerFrameChanged: widget.onPixelsPerFrameChanged,
                  trailing: [
                    IconButton(
                      key: const ValueKey<String>(
                        'timeline-orientation-toggle-button',
                      ),
                      tooltip:
                          widget.orientation == TimelineOrientation.horizontal
                          ? 'Show X-sheet'
                          : 'Show timeline',
                      onPressed: () =>
                          widget.onOrientationChanged(nextOrientation),
                      icon: const Icon(Icons.swap_horiz),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.orientation == TimelineOrientation.horizontal
                ? LayerTimelineGrid(
                    layers: horizontalLayers,
                    activeLayerId: widget.activeLayerId,
                    dragPreview: widget.dragPreview,
                    frameCursor: widget.frameCursor,
                    cacheProgress: widget.cacheProgress,
                    playbackFrameCount: widget.playbackFrameCount,
                    exposureStateForLayer: widget.exposureStateForLayer,
                    frameNameForLayer: widget.frameNameForLayer,
                    onSelectLayer: widget.onSelectLayer,
                    onSelectFrame: widget.onSelectFrame,
                    onScrubFrame: widget.onScrubFrame,
                    onScrubEnd: widget.onScrubEnd,
                    onActivateCell: widget.onActivateCell,
                    instructionDefById: widget.instructionDefById,
                    audioPeaksFor: widget.audioPeaksFor,
                    projectFps: widget.projectFps,
                    showSeconds: widget.showSeconds,
                    onRemoveAudioClip: widget.onRemoveAudioClip,
                    onDropMediaAsset: widget.onDropMediaAsset,
                    onSetAudioClipOffset: widget.onSetAudioClipOffset,
                    audioOffsetDrag: widget.audioOffsetDrag,
                    onSetAudioClipFades: widget.onSetAudioClipFades,
                    onSetAudioClipGain: widget.onSetAudioClipGain,
                    onAddLayer: widget.onAddLayer,
                    onToggleLayerMuted: widget.onToggleLayerMuted,
                    onToggleLayerFillReference:
                        widget.onToggleLayerFillReference,
                    onToggleLayerVisibility: widget.onToggleLayerVisibility,
                    onLayerOpacityChanged: widget.onLayerOpacityChanged,
                    onLayerOpacityChangeEnd: widget.onLayerOpacityChangeEnd,
                    onToggleLayerTimesheet: widget.onToggleLayerTimesheet,
                    onLayerMarkSelected: widget.onLayerMarkSelected,
                    layerFxEnabledOf: widget.layerFxEnabledOf,
                    onToggleLayerFx: widget.onToggleLayerFx,
                    commaDrag: widget.commaDrag,
                    rangeHooks: widget.rangeHooks,
                    runEdit: widget.runEdit,
                    isFrameCached: widget.isFrameCached,
                    metrics: horizontalMetrics,
                    expandedLaneLayerIds: widget.expandedLaneLayerIds,
                    onToggleLayerLanes: widget.onToggleLayerLanes,
                    lanesForLayer: widget.lanesForLayer,
                    laneEdit: widget.laneEdit,
                    onToggleLaneGroup: widget.onToggleLaneGroup,
                    hiddenSections: widget.hiddenSections,
                    onToggleSection: widget.onToggleSection,
                    legend: widget.legend,
                    sectionRail: widget.sectionRail,
                    rowFilter: widget.rowFilter,
                    onSetRowFilter: widget.onSetRowFilter,
                    visibilitySoloEnabled: widget.visibilitySoloEnabled,
                    opacityDragPreview: widget.opacityDragPreview,
                    masterOpacityValue: widget.masterOpacityValue,
                    seSpillInLayerIds: widget.seSpillInLayerIds,
                  )
                : XSheetTimelineGrid(
                    layers: xsheetLayerDisplayOrder(widget.layers),
                    activeLayerId: widget.activeLayerId,
                    dragPreview: widget.dragPreview,
                    frameCursor: widget.frameCursor,
                    cacheProgress: widget.cacheProgress,
                    frameCount: widget.playbackFrameCount,
                    exposureStateForLayer: widget.exposureStateForLayer,
                    frameNameForLayer: widget.frameNameForLayer,
                    onSelectLayer: widget.onSelectLayer,
                    onSelectFrame: widget.onSelectFrame,
                    onScrubFrame: widget.onScrubFrame,
                    onScrubEnd: widget.onScrubEnd,
                    onActivateCell: widget.onActivateCell,
                    instructionDefById: widget.instructionDefById,
                    audioPeaksFor: widget.audioPeaksFor,
                    projectFps: widget.projectFps,
                    showSeconds: widget.showSeconds,
                    onRemoveAudioClip: widget.onRemoveAudioClip,
                    onDropMediaAsset: widget.onDropMediaAsset,
                    onSetAudioClipOffset: widget.onSetAudioClipOffset,
                    audioOffsetDrag: widget.audioOffsetDrag,
                    onSetAudioClipFades: widget.onSetAudioClipFades,
                    onSetAudioClipGain: widget.onSetAudioClipGain,
                    onAddLayer: widget.onAddLayer,
                    onToggleLayerMuted: widget.onToggleLayerMuted,
                    onToggleLayerFillReference:
                        widget.onToggleLayerFillReference,
                    onToggleLayerVisibility: widget.onToggleLayerVisibility,
                    onLayerOpacityChanged: widget.onLayerOpacityChanged,
                    onLayerOpacityChangeEnd: widget.onLayerOpacityChangeEnd,
                    opacityDragPreview: widget.opacityDragPreview,
                    onToggleLayerTimesheet: widget.onToggleLayerTimesheet,
                    onLayerMarkSelected: widget.onLayerMarkSelected,
                    layerFxEnabledOf: widget.layerFxEnabledOf,
                    onToggleLayerFx: widget.onToggleLayerFx,
                    commaDrag: widget.commaDrag,
                    rangeHooks: widget.rangeHooks,
                    runEdit: widget.runEdit,
                    isFrameCached: widget.isFrameCached,
                    metrics: xsheetMetrics,
                    expandedLaneLayerIds: widget.expandedLaneLayerIds,
                    onToggleLayerLanes: widget.onToggleLayerLanes,
                    lanesForLayer: widget.lanesForLayer,
                    laneEdit: widget.laneEdit,
                    onToggleLaneGroup: widget.onToggleLaneGroup,
                    hiddenSections: widget.hiddenSections,
                    rowFilter: widget.rowFilter,
                  ),
          ),
        ],
      ),
    );
  }
}
