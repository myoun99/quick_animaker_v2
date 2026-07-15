import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Listenable, ValueListenable;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../models/canvas_point.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/cut_metadata.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/layer_mark.dart';
import '../models/project.dart';
import '../models/se_audio_spans.dart';
import '../models/timeline_coverage.dart' show TimelineBlockEdge, drawingBlocks;
import '../models/track.dart';
import '../models/track_id.dart';
import '../models/transform_track.dart';
import '../services/audio/audio_peaks_extractor.dart';
import '../services/cut_frame_composite_plan.dart' show layerIdentityPose;
import 'audio/waveform_painter.dart';
import 'panels/panel_scrollbar.dart';
import 'storyboard_cut_fade_policy.dart';
import 'storyboard_layer_policy.dart';
import 'storyboard_timeline_layout.dart';
import 'theme/app_theme.dart';
import 'timeline/layer_label_controls.dart';
import 'widgets/field_slider.dart';
import 'timeline/property_lane_model.dart'
    show PropertyLaneEditCallbacks, PropertyLaneRow;
import 'timeline/se_audio_lane.dart' show SeAudioLaneFrameRow;
import 'timeline/timeline_lane_rows.dart'
    show TimelineLaneControlsRow, TimelineLaneFrameRow;
import 'timeline/transform_lane_policy.dart'
    show transformGroupHeader, transformGroupHeaderLane, transformPropertyLanes;
import 'timeline/timeline_block.dart';
import 'timeline/timeline_drag_preview.dart';
import 'timeline/timeline_cell_style.dart'
    show timelineDrawingInkColor, timelineSelectedFrameBorderColor;
import 'timeline/timeline_exposure_comma_drag_handle.dart'
    show TimelineBlockEdgeGrip;
import 'timeline/timeline_exposure_comma_drag_policy.dart'
    show TimelineCommaDragCallbacks, commaDragFrameDelta;
import 'timeline/timeline_frame_range_policy.dart'
    show
        defaultEndlessRunwayFrames,
        endlessTrailingFrames,
        timelineSecondsLabel;
import 'timeline/timeline_frame_ruler.dart';
import 'timeline/timeline_grid_metrics.dart';
import 'timeline/timeline_playhead.dart' show timelinePlayheadColor;
import 'timeline/timeline_scale.dart';
import 'timeline/timeline_se_row_visual.dart' show SePaperSpan, SeSpanVisual;
import 'timeline/timeline_zoom_anchor_policy.dart';
import 'timeline/upright_vertical_text.dart';

/// Same-track cut reorder request: drop [draggedCutId] at [targetCutIndex]
/// of [targetTrackId]. (Moved here from the retired top-bar CutListBar.)
typedef CutReorderedCallback =
    void Function({
      required CutId draggedCutId,
      required TrackId targetTrackId,
      required int targetCutIndex,
    });

/// The trim-drag hooks the cut edge grips need, mirroring the timeline's
/// comma-drag callbacks: wired to the session's
/// begin/update/end/cancelCutEdgeDrag (live preview, ONE undo per drag).
class StoryboardCutTrimCallbacks {
  const StoryboardCutTrimCallbacks({
    required this.onBegin,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  /// Returns whether the drag may start (the first cut has no start grip
  /// partner, deleted cuts refuse).
  final bool Function(CutId cutId, TimelineBlockEdge edge) onBegin;

  /// Reports the cumulative whole-frame delta since drag start.
  final ValueChanged<int> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
}

/// Whole-block MOVE hooks (R10-④): dragging a cut block horizontally
/// SLIDES the cut along the frame axis (session
/// begin/update/end/cancelCutMoveDrag — live preview, ONE undo per drag).
/// Reordering moved to a long-press lift.
class StoryboardCutMoveCallbacks {
  const StoryboardCutMoveCallbacks({
    required this.onBegin,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  final bool Function(CutId cutId) onBegin;

  /// Reports the cumulative whole-frame delta since drag start.
  final ValueChanged<int> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
}

class StoryboardPanel extends StatefulWidget {
  const StoryboardPanel({
    super.key,
    required this.project,
    required this.activeCutId,
    required this.onCutSelected,
    this.activeLayerId,
    this.onSelectLayer,
    this.onCutReordered,
    this.cutTrim,
    this.cutMove,
    this.pixelsPerFrame = 8,
    this.showSeconds = false,
    this.projectFps = 24,
    this.playheadFrame,
    this.cacheProgress,
    this.onSeekGlobalFrame,
    this.onScrubGlobalFrame,
    this.onScrubEnd,
    this.isFrameCached,
    this.thumbnailFor,
    this.audioPeaksFor,
    this.hiddenWaveformSeRows = const {},
    this.onToggleSeRowWaveform,
    this.expandedSeAudioRows = const {},
    this.onToggleSeRowLane,
    this.expandedTransformTracks = const {},
    this.onToggleTrackLane,
    this.expandedTransformGroups = const {},
    this.onToggleTransformGroup,
    this.cutLaneEditFor,
    this.layerLaneEdit,
    this.activeCutFrameIndex = 0,
    this.onSelectFrameIndex,
    this.poseDisplaySize,
    this.onSetCutFade,
    this.onSetCutFadeTarget,
    this.onToggleLayerVisibility,
    this.onToggleLayerMuted,
    this.onLayerOpacityChanged,
    this.onLayerMarkSelected,
    this.layerFxEnabledOf,
    this.onToggleLayerFx,
    this.cutFxEnabledOf,
    this.onToggleCutFx,
    this.cutPictureVisibleOf,
    this.onToggleCutPictureVisibility,
    this.onSelectSeBlock,
    this.seCommaDrag,
    this.onSetAudioClipOffset,
    this.dragPreview,
  });

  /// Blocks are strictly frame-linear (Premiere-style): a large minimum
  /// width would make neighbours overlap when zoomed out. The tiny floor
  /// only keeps zero-length cuts visible.
  static const double _minBlockWidth = 8;

  // Wide enough for the timeline-style rows (icon + names) the rail mirrors.
  // 140 竊・240 when the S rows gained the timeline-parity layer controls
  // (R4-竭ｨ '・・ｲｽ奝ｵ・ｼ'); the control set needs the width, like the timeline
  // rail's own widening for the fx switch.
  static const double _trackLabelWidth = 240;
  static const double _trackLaneHeight = 64;
  static const double _rulerHeight = 24;

  /// The section-bracket gutter LEFT of the rail (timeline parity, R7-竭､):
  /// one bracket cell per section run 窶・'SE' wrapping a track group's S
  /// rows, 'V TRACK' wrapping its V row 窶・same width as the timeline's
  /// gutter.
  static const double _sectionGutterWidth = 24;
  static const double _timelineTrailingPadding = 12;

  final Project project;

  /// The session's scoped edit-drag channel (R10-③). The panel substitutes
  /// cut-trim previews into [project] INTERNALLY, so a drag step rebuilds
  /// only the cut-layout-dependent pieces (blocks, lanes, ruler width) —
  /// the SE rows (waveforms) and the label rails hold their built
  /// subtrees. Null renders [project] as-is.
  final ValueListenable<TimelineDragPreview?>? dragPreview;

  final CutId activeCutId;
  final ValueChanged<CutId> onCutSelected;

  /// The session's active layer — the S row carrying it gets the timeline
  /// row's active highlight (W4 S-row selection; the V row is not a layer
  /// and stands down). Null = no row highlighted.
  final LayerId? activeLayerId;

  /// Tapping an S-row label selects its TRACK layer (the same session
  /// selection a timeline row tap makes). Null keeps labels display-only.
  final ValueChanged<LayerId>? onSelectLayer;

  /// Dragging a cut block onto another block of the same track reorders the
  /// cuts (same semantics as the top-bar chips). Null disables dragging.
  final CutReorderedCallback? onCutReordered;

  /// Edge-grip trim hooks: the END grip changes a cut's duration (later
  /// cuts ripple), the START grip rolls the boundary with the previous cut.
  /// Null hides the grips.
  final StoryboardCutTrimCallbacks? cutTrim;

  /// Whole-block move hooks (R10-④): a horizontal drag on a block's body
  /// slides the cut (gap authoring + edge-style pushes). Null disables
  /// the slide (blocks then only tap-select / long-press reorder).
  final StoryboardCutMoveCallbacks? cutMove;

  /// Frame-axis zoom, owned by the host (the panel header's shared zoom
  /// slider drives it).
  final double pixelsPerFrame;

  /// Conte-sheet time display for the cut totals: frames (`48f`) or
  /// seconds+frames (`2+00`), toggled by the panel header's shared button.
  final bool showSeconds;
  final int projectFps;

  /// Track-global frame the playhead line sits on (playback position while
  /// playing, the active cut's playhead otherwise) — a LISTENABLE, the
  /// cursor-layer pattern (W4): only the playhead overlay and the ruler
  /// subscribe, so scrub moves and playback ticks never rebuild the
  /// panel's strips/blocks/rails. Null (or a null value) hides the line.
  final ValueListenable<int?>? playheadFrame;

  /// Repaints the ruler's cached-range (green) bar as the prerender cache
  /// fills; null leaves the bar static per build.
  final Listenable? cacheProgress;

  /// Tapping or scrubbing the ruler reports the track-global frame under
  /// the pointer. Null makes the ruler display-only.
  final ValueChanged<int>? onSeekGlobalFrame;

  /// Ruler-drag scrub path: per-move frames go here (cursor-only, no
  /// commit) and the drag's release fires [onScrubEnd] to commit once.
  /// Null falls back to [onSeekGlobalFrame] per move.
  final ValueChanged<int>? onScrubGlobalFrame;
  final VoidCallback? onScrubEnd;

  /// Cached-range resolver in track-global frames for the ruler's green
  /// strip (same look as the timeline header's).
  final bool Function(int globalFrame)? isFrameCached;

  /// Build-time resolver for the cut blocks' first-frame thumbnails (the
  /// store behind it kicks async renders and re-notifies). The image stays
  /// OWNED BY THE RESOLVER 窶・blocks paint it without disposing. Null hides
  /// the thumbnail strip.
  final ui.Image? Function(Cut cut)? thumbnailFor;

  /// Waveform peaks per audio file for the SE rows (null hides waveforms).
  final AudioPeaks? Function(String filePath)? audioPeaksFor;

  /// S rows whose waveform display is toggled OFF (the rail's eye), keyed
  /// by [seRowKey]. View state lives with the host.
  final Set<String> hiddenWaveformSeRows;
  final void Function(Track track, int slot)? onToggleSeRowWaveform;

  /// Twirled-down S rows ([seRowKey]): an enlarged read-only waveform lane
  /// under the row, the timeline Audio lane's storyboard sibling.
  final Set<String> expandedSeAudioRows;
  final void Function(Track track, int slot)? onToggleSeRowLane;

  /// Twirled-down V tracks (track id value): the cut-level Transform group
  /// under the track row (V-track full transform, R6 窶・the AE lanes plus
  /// the cut-fade Opacity strip).
  final Set<String> expandedTransformTracks;
  final void Function(Track track)? onToggleTrackLane;

  /// Twirled-open Transform GROUP HEADERS (AE group collapse, default
  /// collapsed): track id values for the V tracks, [seRowKey]s for the S
  /// rows. One set 窶・the key shapes never collide.
  final Set<String> expandedTransformGroups;
  final void Function(String groupKey)? onToggleTransformGroup;

  /// Per-cut lane edit hooks for the V track's Transform lanes: the host
  /// builds callbacks that edit THAT cut's cut-level transform track (one
  /// undo per edit). The carrier Layer the substrate hands back is
  /// synthetic 窶・the closures capture their cut. Null = display-only.
  final PropertyLaneEditCallbacks? Function(Cut cut)? cutLaneEditFor;

  /// Lane edit hooks for the S rows' Transform lanes 窶・the timeline's
  /// layer-transform lane editing on the ACTIVE cut's slot layers. Null =
  /// display-only.
  final PropertyLaneEditCallbacks? layerLaneEdit;

  /// The ACTIVE cut's playhead (cut-local): the lane labels' value column
  /// and keyframe navigator read here.
  final int activeCutFrameIndex;

  /// Key-navigator jumps (笳 笆ｶ) select this cut-local frame on the session.
  final ValueChanged<int>? onSelectFrameIndex;

  /// The display space the CUT pose resolves over for the value column
  /// (the camera's output frame 窶・the same space playback and the MP4
  /// bake use). Null hides the V lanes' values.
  final CanvasSize? poseDisplaySize;

  /// Commits a cut-fade handle drag (one undo); null makes the Opacity
  /// lane display-only.
  final void Function(CutId cutId, int fadeInFrames, int fadeOutFrames)?
  onSetCutFade;

  /// Sets what a cut's fade fades TO (FO=black / WO=white) 窶・the fade
  /// span's context menu. Null hides the menu.
  final void Function(CutId cutId, CutFadeTarget fadeTarget)?
  onSetCutFadeTarget;

  // --- Timeline-parity layer controls ('・・ｲｽ奝ｵ・ｼ', R4-竭ｨ) -------------------
  // The S rows carry the SAME layer controls as the timeline rows, acting
  // on the ACTIVE cut's slot layer (the storyboard rail is track-global;
  // the active cut supplies the concrete layer). All LayerId-generic 窶・
  // wired to the same session methods the timeline host uses.
  final ValueChanged<LayerId>? onToggleLayerVisibility;
  final ValueChanged<LayerId>? onToggleLayerMuted;
  final void Function(LayerId layerId, double opacity)? onLayerOpacityChanged;
  final void Function(LayerId layerId, LayerMark mark)? onLayerMarkSelected;
  final bool Function(LayerId layerId)? layerFxEnabledOf;
  final ValueChanged<LayerId>? onToggleLayerFx;

  /// V-row display toggles (R9, session view state, ACTIVE-cut scoped like
  /// the S-row layer controls): the fx switch bypasses the cut-level
  /// Transform group (pose + fade) in the playback display, the eye hides
  /// the cut's picture there. Null hides the buttons.
  final bool Function(CutId cutId)? cutFxEnabledOf;
  final ValueChanged<CutId>? onToggleCutFx;
  final bool Function(CutId cutId)? cutPictureVisibleOf;
  final ValueChanged<CutId>? onToggleCutPictureVisibility;

  /// SE block tap-select (timeline parity): selects the cut, its slot layer
  /// and the block's start frame.
  final void Function(CutId cutId, LayerId layerId, int blockStartFrame)?
  onSelectSeBlock;

  /// The timeline's comma-drag hooks for the ACTIVE cut's SE blocks (the
  /// session's exposure edge drags are active-cut scoped 窶・other cuts'
  /// blocks select on tap first). Null hides the grips.
  final TimelineCommaDragCallbacks? seCommaDrag;

  /// The Audio lane's slide edit for the ACTIVE cut's clips (same reused
  /// timeline lane substrate). Null keeps the lane display-only.
  final void Function(LayerId layerId, int clipIndex, int offsetFrames)?
  onSetAudioClipOffset;

  /// The per-S-row view-state key: `<trackId>-<slot>`.
  static String seRowKey(Track track, int slot) => '${track.id.value}-$slot';

  @override
  State<StoryboardPanel> createState() => _StoryboardPanelState();
}

class _StoryboardPanelState extends State<StoryboardPanel> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  int _endlessTrailingFrames = 0;
  double _horizontalScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _horizontalController.addListener(_handleHorizontalScroll);
  }

  @override
  void didUpdateWidget(covariant StoryboardPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Zoom-around-playhead: the playhead stays put on screen through zoom
    // when visible; otherwise (or with no playhead) the leading-edge frame
    // anchors. Shared policy with the timeline grids.
    if (oldWidget.pixelsPerFrame != widget.pixelsPerFrame &&
        _horizontalController.hasClients) {
      _horizontalController.jumpTo(
        zoomAnchoredScrollOffset(
          oldOffset: _horizontalController.position.pixels,
          oldPixelsPerFrame: oldWidget.pixelsPerFrame,
          newPixelsPerFrame: widget.pixelsPerFrame,
          viewportExtent: _horizontalController.position.viewportDimension,
          anchorFrame: widget.playheadFrame?.value,
        ),
      );
    }
  }

  void _handleHorizontalScroll() {
    if (!_horizontalController.hasClients) {
      return;
    }
    final offset = _horizontalController.offset;
    final next = endlessTrailingFrames(
      baseFrameCount: _totalFrames(
        buildStoryboardTimelineLayout(widget.project),
      ),
      currentTrailingFrames: _endlessTrailingFrames,
      scrollOffset: offset,
      viewportExtent: _horizontalController.position.viewportDimension,
      frameCellExtent: _scale.pixelsPerFrame,
    );
    if (next != _endlessTrailingFrames || offset != _horizontalScrollOffset) {
      setState(() {
        _endlessTrailingFrames = next;
        // The shared frame ruler windows itself to the viewport.
        _horizontalScrollOffset = offset;
      });
    }
  }

  TimelineScale get _scale => TimelineScale(
    pixelsPerFrame: widget.pixelsPerFrame,
    minBlockWidth: StoryboardPanel._minBlockWidth,
  );

  @override
  void dispose() {
    _horizontalController.removeListener(_handleHorizontalScroll);
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  /// The widest content edge across every track (blocks can outgrow their
  /// duration via the minimum block width) plus trailing padding 窶・the
  /// ruler and playhead overlay both span it.
  double _timelineContentWidth(
    List<StoryboardTimelineLayoutEntry> entries,
    TimelineScale scale,
  ) {
    var width = 0.0;
    for (final entry in entries) {
      final right =
          scale.leftForFrame(entry.startFrame) +
          scale.widthForDuration(entry.duration);
      if (right > width) {
        width = right;
      }
    }
    return width + StoryboardPanel._timelineTrailingPadding;
  }

  int _totalFrames(List<StoryboardTimelineLayoutEntry> entries) {
    var total = 0;
    for (final entry in entries) {
      if (entry.endFrame > total) {
        total = entry.endFrame;
      }
    }
    return total;
  }

  /// The ACTIVE cut when it lives on [track]; null otherwise (the rail's
  /// lane controls then stand down, like the S-row layer controls).
  Cut? _activeCutOf(Track track) {
    for (final cut in track.cuts) {
      if (cut.id == widget.activeCutId) {
        return cut;
      }
    }
    return null;
  }

  /// The shared lane substrate speaks Layer; the V track's cut-level lanes
  /// ride a synthetic carrier 窶・its id only feeds the widget keys, the
  /// edit closures capture their cut ([StoryboardPanel.cutLaneEditFor]).
  Layer _vLaneCarrier(String seed) =>
      Layer(id: LayerId('v-$seed'), name: 'V', frames: const []);

  /// The Transform-group member lanes of one V track, header first: the
  /// AE lane list valued against the ACTIVE cut (label-only rows while the
  /// active cut lives elsewhere). The Opacity lane stays LAST 窶・its strip
  /// is the cut-fade envelope row, and the labels must line up.
  List<PropertyLaneRow> _cutTransformLanes(Track track, Cut? activeCut) {
    final expanded = widget.expandedTransformGroups.contains(track.id.value);
    final displaySize = widget.poseDisplaySize;
    final lanes = activeCut == null
        ? transformPropertyLanes(
            TransformTrack.empty(),
            includeAnchorAndOpacity: true,
          )
        : transformPropertyLanes(
            activeCut.transformTrack,
            includeAnchorAndOpacity: true,
            poseAt: displaySize == null
                ? null
                : (frame) => cutPoseAt(activeCut, frame, displaySize),
            anchorAt: displaySize == null
                ? null
                : (frame) =>
                      cutAnchorPointAt(activeCut, frame) ??
                      CanvasPoint(
                        x: displaySize.width / 2,
                        y: displaySize.height / 2,
                      ),
            opacityAt: activeCut.fadeOpacityAt,
          );
    return [
      transformGroupHeader(expanded: expanded),
      if (expanded) ...lanes.where((lane) => !lane.isGroupHeader),
    ];
  }

  /// One S row's Transform-group lanes, header first, valued against the
  /// ACTIVE cut's slot layer (the same raw-track resolution the timeline's
  /// value column uses 窶・fx bypass never touches authoring values).
  List<PropertyLaneRow> _seTransformLanes(
    Track track,
    int slot,
    Cut? activeCut,
    Layer? layer,
  ) {
    final expanded = widget.expandedTransformGroups.contains(
      StoryboardPanel.seRowKey(track, slot),
    );
    final lanes = layer == null || activeCut == null
        ? transformPropertyLanes(
            TransformTrack.empty(),
            includeAnchorAndOpacity: true,
          )
        : transformPropertyLanes(
            layer.transformTrack,
            includeAnchorAndOpacity: true,
            poseAt: (frame) => layer.transformTrack.resolveAt(
              frameIndex: frame,
              orElse: () => layerIdentityPose(activeCut.canvasSize),
            ),
            anchorAt: (frame) =>
                resolveAnchorTrackAt(layer.transformTrack.anchorPoint, frame) ??
                CanvasPoint(
                  x: activeCut.canvasSize.width / 2,
                  y: activeCut.canvasSize.height / 2,
                ),
            opacityAt: (frame) =>
                resolveOpacityTrackAt(layer.transformTrack.opacity, frame),
          );
    return [
      transformGroupHeader(expanded: expanded),
      if (expanded) ...lanes.where((lane) => !lane.isGroupHeader),
    ];
  }

  /// Transform-lane rail label rows on the shared substrate ([lanes] from
  /// [_cutTransformLanes]/[_seTransformLanes]): the group header row plus
  /// the twirled-open member lanes, storyboard-prefixed. [active] gates
  /// the navigator's frame jumps and value edits to the active cut.
  List<Widget> _transformLaneLabels({
    required Layer carrier,
    required String groupKey,
    required List<PropertyLaneRow> lanes,
    required PropertyLaneEditCallbacks? laneEdit,
    required bool active,
  }) {
    final metrics = TimelineGridMetrics(
      frameCellWidth: widget.pixelsPerFrame,
      layerRowHeight: _transformLaneHeight - 2,
    );
    final onToggleGroup = widget.onToggleTransformGroup;
    return [
      for (final lane in lanes)
        TimelineLaneControlsRow(
          layer: carrier,
          lane: lane,
          metrics: metrics,
          width: StoryboardPanel._trackLabelWidth,
          height: _transformLaneHeight,
          currentFrameIndex: widget.activeCutFrameIndex,
          onSelectFrame: active ? widget.onSelectFrameIndex : null,
          laneEdit: lane.isGroupHeader || !active ? null : laneEdit,
          onToggleLaneGroup: onToggleGroup == null
              ? null
              : (_, _) => onToggleGroup(groupKey),
          keyPrefix: 'storyboard',
        ),
    ];
  }

  /// The 2px section divider overlaying the top of a track group's FIRST
  /// rail row 窶・zero height cost, so the rail and the strips column (which
  /// carries no divider element) stay row-for-row height-synced.
  Widget _withRailDivider(Track track, Widget row) {
    return Stack(
      children: [
        row,
        Positioned(
          top: 0,
          left: 0,
          width: StoryboardPanel._trackLabelWidth,
          height: 2,
          child: IgnorePointer(
            child: Container(
              key: ValueKey<String>(
                'storyboard-section-divider-rail-${track.id.value}',
              ),
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _seLabelRow(Track track, int slot) {
    final trackLayer = _trackSeAt(track, slot);
    return _StoryboardSeLabel(
      track: track,
      slot: slot,
      active:
          trackLayer != null &&
          widget.activeLayerId != null &&
          trackLayer.id == widget.activeLayerId,
      onSelectLayer: widget.onSelectLayer,
      waveformVisible: !widget.hiddenWaveformSeRows.contains(
        StoryboardPanel.seRowKey(track, slot),
      ),
      onToggleWaveform: widget.onToggleSeRowWaveform == null
          ? null
          : () => widget.onToggleSeRowWaveform!(track, slot),
      laneExpanded: widget.expandedSeAudioRows.contains(
        StoryboardPanel.seRowKey(track, slot),
      ),
      onToggleLane: widget.onToggleSeRowLane == null
          ? null
          : () => widget.onToggleSeRowLane!(track, slot),
      activeLayer: _activeSlotLayerOf(track, widget.activeCutId, slot),
      onToggleLayerVisibility: widget.onToggleLayerVisibility,
      onToggleLayerMuted: widget.onToggleLayerMuted,
      onLayerOpacityChanged: widget.onLayerOpacityChanged,
      onLayerMarkSelected: widget.onLayerMarkSelected,
      layerFxEnabledOf: widget.layerFxEnabledOf,
      onToggleLayerFx: widget.onToggleLayerFx,
    );
  }

  /// One track group's rail rows in TIMELINE order (R6 B3, R7-竭｣): the S
  /// rows (each with its twirled-down Audio lane and Transform group)
  /// ABOVE the V track row and ITS Transform group, slots counting UP from
  /// the bottom like the timeline's layer stack (S1 sits right above V,
  /// S2 above it); the section divider overlays the group's first row.
  List<Widget> _railRowsForTrack(Track track, int index) {
    final activeCut = _activeCutOf(track);
    final rows = <Widget>[
      for (var slot = _seSlotCount(track) - 1; slot >= 0; slot--) ...[
        _seLabelRow(track, slot),
        if (widget.expandedSeAudioRows.contains(
          StoryboardPanel.seRowKey(track, slot),
        )) ...[
          // Audio leads the S twirl-down (the row's main tool, timeline
          // parity); the Transform group sits below, collapsed default.
          _StoryboardLaneLabel(
            laneKey:
                'storyboard-lane-label-'
                '${track.id.value}'
                '-s${slot + 1}-audio',
            label: 'Audio',
            icon: Icons.graphic_eq,
            height: _audioLaneHeight,
          ),
          ..._transformLaneLabels(
            carrier:
                _trackSeAt(track, slot) ??
                _vLaneCarrier('se-${StoryboardPanel.seRowKey(track, slot)}'),
            groupKey: StoryboardPanel.seRowKey(track, slot),
            lanes: _seTransformLanes(
              track,
              slot,
              activeCut,
              _trackSeAt(track, slot),
            ),
            laneEdit: widget.layerLaneEdit,
            active: activeCut != null && _trackSeAt(track, slot) != null,
          ),
        ],
      ],
      _StoryboardTrackLabel(
        track: track,
        trackLabel: 'V${index + 1}',
        laneExpanded: widget.expandedTransformTracks.contains(track.id.value),
        onToggleLane: widget.onToggleTrackLane == null
            ? null
            : () => widget.onToggleTrackLane!(track),
        activeCut: activeCut,
        cutFxEnabledOf: widget.cutFxEnabledOf,
        onToggleCutFx: widget.onToggleCutFx,
        cutPictureVisibleOf: widget.cutPictureVisibleOf,
        onToggleCutPictureVisibility: widget.onToggleCutPictureVisibility,
      ),
      if (widget.expandedTransformTracks.contains(track.id.value))
        ..._transformLaneLabels(
          carrier: _vLaneCarrier(track.id.value),
          groupKey: track.id.value,
          lanes: _cutTransformLanes(track, activeCut),
          laneEdit: activeCut == null
              ? null
              : widget.cutLaneEditFor?.call(activeCut),
          active: activeCut != null,
        ),
    ];
    return [_withRailDivider(track, rows.first), ...rows.skip(1)];
  }

  /// Pixel height of one track group's S-row section in the rail (rows
  /// plus twirled-down lanes) 窶・the section bracket's cell must match the
  /// rows exactly, so this mirrors [_railRowsForTrack]'s conditionals over
  /// the same height constants (rows stack flush, R7-竭､).
  double _seSectionExtent(Track track) {
    final activeCut = _activeCutOf(track);
    var extent = 0.0;
    for (var slot = 0; slot < _seSlotCount(track); slot++) {
      extent += _seRowHeight;
      if (widget.expandedSeAudioRows.contains(
        StoryboardPanel.seRowKey(track, slot),
      )) {
        extent += _audioLaneHeight;
        extent +=
            _seTransformLanes(
              track,
              slot,
              activeCut,
              _trackSeAt(track, slot),
            ).length *
            _transformLaneHeight;
      }
    }
    return extent;
  }

  /// Pixel height of one track group's V section in the rail (the track
  /// row plus its twirled-down Transform group) 窶・see [_seSectionExtent].
  double _vSectionExtent(Track track) {
    var extent = StoryboardPanel._trackLaneHeight;
    if (widget.expandedTransformTracks.contains(track.id.value)) {
      extent +=
          _cutTransformLanes(track, _activeCutOf(track)).length *
          _transformLaneHeight;
    }
    return extent;
  }

  /// One section-bracket cell 窶・the timeline gutter's exact visual
  /// language (surface-low fill, outline border, upright stacked label).
  Widget _sectionBracket({
    required String keySuffix,
    required String label,
    required double height,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey<String>('storyboard-section-bracket-$keySuffix'),
      width: StoryboardPanel._sectionGutterWidth,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outline, width: 1),
      ),
      child: Center(
        child: ClipRect(
          child: UprightVerticalText(
            text: label,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              height: 1.15,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  /// One track group's gutter cells: the SE bracket over its S rows (when
  /// any) and the V TRACK bracket over its track row and lanes.
  List<Widget> _sectionBracketsForTrack(Track track) {
    final seExtent = _seSectionExtent(track);
    return [
      if (seExtent > 0)
        _sectionBracket(
          keySuffix: 'se-${track.id.value}',
          label: 'SE',
          height: seExtent,
        ),
      _sectionBracket(
        keySuffix: 'v-${track.id.value}',
        label: 'V TRACK',
        height: _vSectionExtent(track),
      ),
    ];
  }

  /// One track group's strip rows, mirroring [_railRowsForTrack] row for
  /// row (heights must stay in lockstep 窶・the two columns share no
  /// scaffolding).
  List<Widget> _stripRowsForTrack(
    Track track,
    int index,
    List<StoryboardTimelineLayoutEntry> entries,
    double width,
    TimelineScale scale,
    List<Widget> seRows,
  ) {
    return [
      // Prebuilt from the RAW project outside the drag-preview builder
      // (R10-③): identical instances per step = subtree rebuilds skipped.
      ...seRows,
      _StoryboardTrackRow(
        track: track,
        layoutEntries: entries,
        activeCutId: widget.activeCutId,
        onCutSelected: widget.onCutSelected,
        onCutReordered: widget.onCutReordered,
        cutTrim: widget.cutTrim,
        cutMove: widget.cutMove,
        thumbnailFor: widget.thumbnailFor,
        timelineScale: scale,
        showSeconds: widget.showSeconds,
        projectFps: widget.projectFps,
      ),
      if (widget.expandedTransformTracks.contains(track.id.value))
        ..._cutTransformLaneStrips(track, index, entries, width, scale),
    ];
  }

  /// One track's SE strip rows (+ twirled-down audio/transform lanes) —
  /// track-global content, built from the base layout.
  List<Widget> _seStripRowsForTrack(
    Track track,
    int index,
    List<StoryboardTimelineLayoutEntry> entries,
    double width,
    TimelineScale scale,
  ) {
    return [
      for (var slot = _seSlotCount(track) - 1; slot >= 0; slot--) ...[
        _StoryboardSeRow(
          trackIndex: index,
          slot: slot,
          layer: _trackSeAt(track, slot),
          layoutEntries: entries,
          width: width,
          timelineScale: scale,
          projectFps: widget.projectFps,
          audioPeaksFor:
              widget.hiddenWaveformSeRows.contains(
                StoryboardPanel.seRowKey(track, slot),
              )
              ? null
              : widget.audioPeaksFor,
          activeCutId: widget.activeCutId,
          onSelectSeBlock: widget.onSelectSeBlock,
          seCommaDrag: widget.seCommaDrag,
        ),
        if (widget.expandedSeAudioRows.contains(
          StoryboardPanel.seRowKey(track, slot),
        )) ...[
          _StoryboardAudioLaneRow(
            trackIndex: index,
            slot: slot,
            layer: _trackSeAt(track, slot),
            layoutEntries: entries,
            width: width,
            timelineScale: scale,
            projectFps: widget.projectFps,
            audioPeaksFor: widget.audioPeaksFor,
            activeCutId: widget.activeCutId,
            onSetAudioClipOffset: widget.onSetAudioClipOffset,
          ),
          ..._seTransformLaneStrips(track, index, slot, entries, width, scale),
        ],
      ],
    ];
  }

  /// Resolves [laneId] against a transform [track] for one strip span.
  PropertyLaneRow _laneOfTrack(TransformTrack track, String laneId) {
    if (laneId == transformGroupHeaderLane.laneId) {
      return transformGroupHeaderLane;
    }
    return transformPropertyLanes(
      track,
      includeAnchorAndOpacity: true,
    ).firstWhere((lane) => lane.laneId == laneId);
  }

  /// The V track's Transform strip rows: the group header band plus,
  /// twirled open, the AE lanes' key-marker strips 窶・and the cut-fade
  /// envelope row AS the Opacity strip (fade handles unchanged, canonical
  /// key policy intact).
  List<Widget> _cutTransformLaneStrips(
    Track track,
    int trackIndex,
    List<StoryboardTimelineLayoutEntry> entries,
    double width,
    TimelineScale scale,
  ) {
    final expanded = widget.expandedTransformGroups.contains(track.id.value);
    Widget strip(String laneId) => _StoryboardLaneStripRow(
      rowKey: 'storyboard-cut-lane-row-$trackIndex-$laneId',
      layoutEntries: entries,
      width: width,
      timelineScale: scale,
      activeCutId: widget.activeCutId,
      laneOf: (cut) => (
        _vLaneCarrier(cut.id.value),
        _laneOfTrack(cut.transformTrack, laneId),
      ),
      laneEditFor: widget.cutLaneEditFor,
    );
    return [
      strip(transformGroupHeaderLane.laneId),
      if (expanded) ...[
        strip('anchor-point'),
        strip('position'),
        strip('scale'),
        strip('rotation'),
        _StoryboardOpacityLaneRow(
          trackIndex: trackIndex,
          layoutEntries: entries,
          width: width,
          timelineScale: scale,
          onSetCutFade: widget.onSetCutFade,
          onSetCutFadeTarget: widget.onSetCutFadeTarget,
        ),
      ],
    ];
  }

  /// One S row's Transform strip rows: per-cut key-marker strips on the
  /// slot layers' OWN tracks (cuts without the slot skip), editing gated
  /// to the active cut.
  List<Widget> _seTransformLaneStrips(
    Track track,
    int trackIndex,
    int slot,
    List<StoryboardTimelineLayoutEntry> entries,
    double width,
    TimelineScale scale,
  ) {
    final rowKey = StoryboardPanel.seRowKey(track, slot);
    final expanded = widget.expandedTransformGroups.contains(rowKey);
    final layerLaneEdit = widget.layerLaneEdit;
    Widget strip(String laneId) => _StoryboardLaneStripRow(
      rowKey: 'storyboard-se-lane-row-$trackIndex-${slot + 1}-$laneId',
      layoutEntries: entries,
      width: width,
      timelineScale: scale,
      activeCutId: widget.activeCutId,
      laneOf: (cut) {
        final layer = _trackSeAt(track, slot);
        if (layer == null) {
          return null;
        }
        return (layer, _laneOfTrack(layer.transformTrack, laneId));
      },
      laneEditFor: layerLaneEdit == null ? null : (_) => layerLaneEdit,
    );
    return [
      strip(transformGroupHeaderLane.laneId),
      if (expanded) ...[
        strip('anchor-point'),
        strip('position'),
        strip('scale'),
        strip('rotation'),
        strip('opacity'),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    // SE rows are built OUTSIDE the drag-preview builder from the RAW
    // project (R10-③): their content is track-global, so a cut trim never
    // changes them — handing the per-step rebuild IDENTICAL row instances
    // lets Flutter skip their whole subtrees (waveform painters included).
    // The trade: an in-flight trim doesn't slide their cut-boundary marks
    // until release. SE comma drags edit the ACTIVE layer through the
    // timeline gates, unaffected here.
    final seStripRowsByTrack = _seStripRowsByTrack();
    final dragPreview = widget.dragPreview;
    if (dragPreview == null) {
      return _buildBody(context, widget.project, seStripRowsByTrack);
    }
    return ValueListenableBuilder<TimelineDragPreview?>(
      valueListenable: dragPreview,
      builder: (context, preview, _) => _buildBody(
        context,
        projectWithTimelineDragPreview(widget.project, preview),
        seStripRowsByTrack,
      ),
    );
  }

  /// The base-layout SE strip rows (+ their twirled-down lanes) per track
  /// index — computed once per PANEL build and reused across drag-preview
  /// steps.
  List<List<Widget>> _seStripRowsByTrack() {
    final layoutEntries = buildStoryboardTimelineLayout(widget.project);
    final scale = _scale;
    final contentWidth = _contentWidthFor(layoutEntries, scale);
    return [
      for (var index = 0; index < widget.project.tracks.length; index++)
        _seStripRowsForTrack(
          widget.project.tracks[index],
          index,
          layoutEntries
              .where((entry) => entry.trackIndex == index)
              .toList(growable: false),
          contentWidth,
          scale,
        ),
    ];
  }

  /// The scroll content's full width for [layoutEntries] (cuts + the
  /// endless runway).
  double _contentWidthFor(
    List<StoryboardTimelineLayoutEntry> layoutEntries,
    TimelineScale scale,
  ) {
    final totalFrames = _totalFrames(layoutEntries);
    final renderedFrames =
        totalFrames +
        math.max<int>(_endlessTrailingFrames, defaultEndlessRunwayFrames);
    return math.max(
      _timelineContentWidth(layoutEntries, scale),
      scale.leftForFrame(renderedFrames) +
          StoryboardPanel._timelineTrailingPadding,
    );
  }

  Widget _buildBody(
    BuildContext context,
    Project project,
    List<List<Widget>> seStripRowsByTrack,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final layoutEntries = buildStoryboardTimelineLayout(project);
    final scale = _scale;
    final totalFrames = _totalFrames(layoutEntries);
    // Endless frame axis: the ruler (and scrollable area) always shows a
    // runway past the cuts, growing with how far the user has scrolled
    // (short content could never scroll into a grow-on-approach runway
    // otherwise); seeks stay content-bound.
    final renderedFrames =
        totalFrames +
        math.max<int>(_endlessTrailingFrames, defaultEndlessRunwayFrames);
    final contentWidth = _contentWidthFor(layoutEntries, scale);
    // The playhead + green bar repaint through their own listenables (the
    // cursor-layer pattern) — the ruler's overlay PAINTER and the playhead
    // overlay subscribe below, nothing else in this build does.
    final playheadListenable = widget.playheadFrame;

    return DecoratedBox(
      key: const ValueKey<String>('storyboard-panel'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PINNED RULER: the frame ruler sits ABOVE the vertical scroll
            // area (the timeline's sticky-header pattern) so it stays put
            // while tracks and SE rows scroll under it; it follows the
            // horizontal scroll by translation.
            Padding(
              padding: const EdgeInsets.only(right: panelScrollbarGutter),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width:
                        StoryboardPanel._sectionGutterWidth +
                        StoryboardPanel._trackLabelWidth,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportWidth = constraints.hasBoundedWidth
                            ? constraints.maxWidth
                            : contentWidth;
                        return SizedBox(
                          height: StoryboardPanel._rulerHeight,
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.topLeft,
                              minWidth: contentWidth,
                              maxWidth: contentWidth,
                              minHeight: StoryboardPanel._rulerHeight,
                              maxHeight: StoryboardPanel._rulerHeight,
                              child: Transform.translate(
                                offset: Offset(-_horizontalScrollOffset, 0),
                                child: _StoryboardRuler(
                                  width: contentWidth,
                                  renderedFrames: renderedFrames,
                                  contentFrames: totalFrames,
                                  playhead: playheadListenable,
                                  cacheProgress: widget.cacheProgress,
                                  scrollOffset: _horizontalScrollOffset,
                                  viewportWidth: viewportWidth,
                                  timelineScale: scale,
                                  onSeekGlobalFrame: widget.onSeekGlobalFrame,
                                  onScrubGlobalFrame: widget.onScrubGlobalFrame,
                                  onScrubEnd: widget.onScrubEnd,
                                  isFrameCached: widget.isFrameCached,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PanelScrollbar(
                controller: _verticalController,
                child: SingleChildScrollView(
                  key: const ValueKey<String>('storyboard-vertical-viewport'),
                  controller: _verticalController,
                  padding: const EdgeInsets.only(right: panelScrollbarGutter),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section brackets lead the rail (timeline parity,
                      // R7-竭､): 'SE' wraps each group's S rows, 'V TRACK'
                      // its track row 窶・fixed-height cells computed from
                      // the same constants the rows use.
                      SizedBox(
                        key: const ValueKey<String>('storyboard-section-rail'),
                        width: StoryboardPanel._sectionGutterWidth,
                        child: Column(
                          children: [
                            for (final track in project.tracks)
                              ..._sectionBracketsForTrack(track),
                          ],
                        ),
                      ),
                      SizedBox(
                        key: const ValueKey<String>(
                          'storyboard-track-label-rail',
                        ),
                        width: StoryboardPanel._trackLabelWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Track groups in TIMELINE order (R6 B3): the
                            // S rows sit ABOVE their V track, slots
                            // bottom-up like the timeline (top-down
                            // S2, S1, V 窶・R7-竭｣).
                            for (
                              var index = 0;
                              index < project.tracks.length;
                              index++
                            )
                              ..._railRowsForTrack(
                                project.tracks[index],
                                index,
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: PanelScrollbar(
                          controller: _horizontalController,
                          child: SingleChildScrollView(
                            key: const ValueKey<String>(
                              'storyboard-timeline-horizontal-viewport',
                            ),
                            controller: _horizontalController,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(
                              bottom: panelScrollbarGutter,
                            ),
                            child: Stack(
                              children: [
                                // Frame grid lines under the blocks:
                                // the runway reads as endless frame
                                // cells, like the timeline's grid
                                // (painted 窶・costs nothing per frame).
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        key: const ValueKey<String>(
                                          'storyboard-frame-lines',
                                        ),
                                        painter: _StoryboardFrameLinesPainter(
                                          pixelsPerFrame: scale.pixelsPerFrame,
                                          color: colorScheme.outlineVariant
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // RepaintBoundary (R12-⑥): the playhead
                                // overlay above moves every playback tick;
                                // without the boundary each move re-
                                // rasterizes every strip, thumbnail and
                                // waveform in this column.
                                RepaintBoundary(
                                  child: Column(
                                    key: const ValueKey<String>(
                                      'storyboard-timeline-scroll-content',
                                    ),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Width driver: the scroll content spans
                                      // the full frame runway even when every
                                      // row is narrower (the pinned ruler used
                                      // to do this from inside the content).
                                      SizedBox(width: contentWidth),
                                      // Track groups in TIMELINE order (R6
                                      // B3), mirroring the rail exactly 窶・
                                      // row for row, height for height.
                                      for (
                                        var index = 0;
                                        index < project.tracks.length;
                                        index++
                                      )
                                        ..._stripRowsForTrack(
                                          project.tracks[index],
                                          index,
                                          layoutEntries
                                              .where(
                                                (entry) =>
                                                    entry.trackIndex == index,
                                              )
                                              .toList(growable: false),
                                          contentWidth,
                                          scale,
                                          index < seStripRowsByTrack.length
                                              ? seStripRowsByTrack[index]
                                              : const [],
                                        ),
                                    ],
                                  ),
                                ),
                                if (playheadListenable != null)
                                  // Frame-wide accent tint only 窶・no solid
                                  // edge line over the blocks (user
                                  // direction); the ruler carries its own
                                  // current-frame highlight. Subscribes to
                                  // the cursor itself: a tick moves THIS
                                  // overlay, the blocks never rebuild.
                                  ValueListenableBuilder<int?>(
                                    valueListenable: playheadListenable,
                                    builder: (context, playheadFrame, _) =>
                                        playheadFrame == null
                                        ? const SizedBox.shrink()
                                        : Positioned(
                                            key: const ValueKey<String>(
                                              'storyboard-playhead',
                                            ),
                                            left: scale.leftForFrame(
                                              playheadFrame,
                                            ),
                                            top: 0,
                                            bottom: 0,
                                            width: scale.pixelsPerFrame,
                                            child: IgnorePointer(
                                              child: ColoredBox(
                                                color: timelinePlayheadColor
                                                    .withValues(alpha: 0.18),
                                              ),
                                            ),
                                          ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The compact cut-management toolbar at the top of the storyboard: the
/// storyboard owns the cut lifecycle, so new/rename/note/canvas/duplicate/
/// move/delete live here (icon-only with tooltips, acting on the active
/// cut). Zoom lives in the panel header's shared slider.
/// The Premiere-style frame ruler across the top of the track area: frame
/// ticks and 1-based labels on the shared [TimelineScale], scrolling with
/// the blocks. Tapping or dragging seeks via [onSeekGlobalFrame].
/// The storyboard's frame ruler IS the timeline's ([TimelineFrameRuler] with
/// the cell extent carrying the storyboard zoom): identical header cells,
/// adaptive labels, runway dimming and the cut-end boundary line. The row is
/// windowed to the scrolled viewport because the storyboard's scroll content
/// is not otherwise virtualized.
class _StoryboardRuler extends StatelessWidget {
  const _StoryboardRuler({
    required this.width,
    required this.renderedFrames,
    required this.contentFrames,
    required this.playhead,
    required this.cacheProgress,
    required this.scrollOffset,
    required this.viewportWidth,
    required this.timelineScale,
    required this.onSeekGlobalFrame,
    required this.onScrubGlobalFrame,
    required this.onScrubEnd,
    required this.isFrameCached,
  });

  static const int _overscanCells = 4;

  final double width;

  /// Rendered range 窶・includes the endless-axis runway past the cuts;
  /// seeks may land anywhere in it (over-end selection like the timeline).
  final int renderedFrames;

  /// The cuts' actual end (runway dimming + the cut-end boundary line).
  final int contentFrames;

  /// The playhead + cache-warm signals, consumed by the cursor overlay
  /// PAINTER only (R12-B): a playback tick or a warming frame repaints
  /// one thin layer — the header cells never rebuild. At storyboard zoom
  /// there are far more of them than in the timeline, which is exactly
  /// why the old rebuild-per-tick ruler showed up as fixed frame drops.
  final ValueListenable<int?>? playhead;
  final Listenable? cacheProgress;
  final double scrollOffset;
  final double viewportWidth;
  final TimelineScale timelineScale;
  final ValueChanged<int>? onSeekGlobalFrame;

  /// Drag-scrub path (cursor-only per move + one commit on release); null
  /// falls back to per-move seeks.
  final ValueChanged<int>? onScrubGlobalFrame;
  final VoidCallback? onScrubEnd;

  final bool Function(int globalFrame)? isFrameCached;

  void _reportFrame(ValueChanged<int>? sink, int frame) {
    if (sink == null || contentFrames <= 0 || renderedFrames <= 0) {
      return;
    }
    sink(frame.clamp(0, renderedFrames - 1));
  }

  void _seekFrame(int frame) => _reportFrame(onSeekGlobalFrame, frame);

  void _scrubAt(double dx) {
    _reportFrame(
      onScrubGlobalFrame ?? onSeekGlobalFrame,
      (dx / timelineScale.pixelsPerFrame).floor(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cellWidth = timelineScale.pixelsPerFrame;
    final startIndex = math.max(
      0,
      (scrollOffset / cellWidth).floor() - _overscanCells,
    );
    final endIndexExclusive = math.min(
      renderedFrames,
      ((scrollOffset + viewportWidth) / cellWidth).ceil() + _overscanCells,
    );
    final metrics = TimelineGridMetrics(
      frameCellWidth: cellWidth,
      layerRowHeight: StoryboardPanel._rulerHeight,
      layerControlsWidth: 0,
      verticalScrollbarWidth: 0,
    );

    return GestureDetector(
      key: const ValueKey<String>('storyboard-ruler'),
      behavior: HitTestBehavior.translucent,
      // .down reports the true pointer-down position, so a scrub seeks the
      // pressed frame first instead of the post-slop position. Plain taps
      // are the header cells' own InkWells.
      dragStartBehavior: DragStartBehavior.down,
      // Scrubbing claims horizontal drags on the ruler strip only; the
      // track rows below still pan the panel. Moves ride the cursor path
      // (no commit); the release commits once. Header-cell taps stay full
      // seeks through their own InkWells.
      onHorizontalDragStart: (details) => _scrubAt(details.localPosition.dx),
      onHorizontalDragUpdate: (details) => _scrubAt(details.localPosition.dx),
      onHorizontalDragEnd: (_) => onScrubEnd?.call(),
      onHorizontalDragCancel: () => onScrubEnd?.call(),
      child: SizedBox(
        width: width,
        height: StoryboardPanel._rulerHeight,
        child: Stack(
          children: [
            // STATIC header cells: cursor- and cache-independent — ticks
            // and warming frames never rebuild them.
            TimelineFrameRuler(
              key: const ValueKey<String>('storyboard-frame-ruler'),
              frameStartIndex: startIndex,
              frameEndIndexExclusive: math.max(startIndex, endIndexExclusive),
              currentFrameIndex: -1,
              playbackFrameCount: contentFrames,
              leadingFrameSpacerWidth: startIndex * cellWidth,
              trailingFrameSpacerWidth: math.max(
                0,
                (renderedFrames - math.max(startIndex, endIndexExclusive)) *
                    cellWidth,
              ),
              metrics: metrics,
              onSelectFrame: _seekFrame,
            ),
            // The moving parts REPAINT only: current-frame tint + green
            // cached bar, one thin isolated layer.
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey<String>(
                      'storyboard-ruler-cursor-overlay',
                    ),
                    painter: _StoryboardRulerCursorPainter(
                      playhead: playhead,
                      cacheProgress: cacheProgress,
                      frameStartIndex: startIndex,
                      frameEndIndexExclusive: math.max(
                        startIndex,
                        endIndexExclusive,
                      ),
                      contentFrames: contentFrames,
                      cellWidth: cellWidth,
                      isFrameCached: isFrameCached,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The storyboard ruler's per-tick layer: the current-frame tint and the
/// green cached-range bar painted OVER the static header cells, driven by
/// [CustomPainter.repaint] — no widget rebuilds on ticks or cache warms.
class _StoryboardRulerCursorPainter extends CustomPainter {
  _StoryboardRulerCursorPainter({
    required this.playhead,
    required Listenable? cacheProgress,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.contentFrames,
    required this.cellWidth,
    required this.isFrameCached,
  }) : super(repaint: Listenable.merge([?playhead, ?cacheProgress]));

  final ValueListenable<int?>? playhead;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final int contentFrames;
  final double cellWidth;
  final bool Function(int globalFrame)? isFrameCached;

  /// The AE-style cached-range green (the header cells' own strip color).
  static const Color _cachedBarColor = Color(0xFF54B435);

  @override
  void paint(Canvas canvas, Size size) {
    final cached = isFrameCached;
    if (cached != null) {
      final barPaint = Paint()..color = _cachedBarColor;
      final end = math.min(frameEndIndexExclusive, contentFrames);
      var runStart = -1;
      // Consecutive cached frames coalesce into one rect per run.
      for (var frame = frameStartIndex; frame <= end; frame += 1) {
        if (frame < end && cached(frame)) {
          runStart = runStart < 0 ? frame : runStart;
          continue;
        }
        if (runStart >= 0) {
          canvas.drawRect(
            Rect.fromLTWH(
              runStart * cellWidth,
              size.height - 3,
              (frame - runStart) * cellWidth,
              3,
            ),
            barPaint,
          );
          runStart = -1;
        }
      }
    }

    final frame = playhead?.value;
    if (frame != null &&
        frame >= frameStartIndex &&
        frame < frameEndIndexExclusive) {
      // Matches the header cell's selected fill: the same tint over the
      // same surface the cell would have blended it onto.
      canvas.drawRect(
        Rect.fromLTWH(frame * cellWidth, 0, cellWidth, size.height),
        Paint()
          ..color = timelineSelectedFrameBorderColor.withValues(alpha: 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(_StoryboardRulerCursorPainter oldDelegate) =>
      oldDelegate.frameStartIndex != frameStartIndex ||
      oldDelegate.frameEndIndexExclusive != frameEndIndexExclusive ||
      oldDelegate.contentFrames != contentFrames ||
      oldDelegate.cellWidth != cellWidth ||
      !identical(oldDelegate.playhead, playhead) ||
      !identical(oldDelegate.isFrameCached, isFrameCached);
}

/// SE rows under a track: one per SE slot, S1ﾂｷS2窶ｦ like the sheet columns.
// 22 竊・30 with the timeline-parity S-row controls (mute/eye/opacity).
const double _seRowHeight = 30;

/// Twirl-down lane heights: the enlarged waveform strip, the cut-fade
/// (Opacity) envelope lane and the Transform lanes (labels and strips
/// share these 窶・the rail and strips columns must stay height-synced).
const double _audioLaneHeight = 36;
const double _opacityLaneHeight = 26;
const double _transformLaneHeight = 26;

/// The track's SE row count: SE rows are TRACK-owned (list order is THE
/// ordering every panel renders 窶・timeline parity by identity).
int _seSlotCount(Track track) => track.seLayers.length;

/// The [slot]th TRACK-owned SE layer (global-frame timeline); null when
/// the track has fewer rows.
Layer? _trackSeAt(Track track, int slot) =>
    slot >= 0 && slot < track.seLayers.length ? track.seLayers[slot] : null;

/// The [slot]th SE layer for the rail's timeline-parity controls; null
/// while the active cut lives on another track (the controls then hide 窶・
/// same stand-down as before, though the layer identity no longer depends
/// on the cut).
Layer? _activeSlotLayerOf(Track track, CutId activeCutId, int slot) {
  if (!track.cuts.any((cut) => cut.id == activeCutId)) {
    return null;
  }
  return _trackSeAt(track, slot);
}

/// SE slot rows in the rail: the same bordered-row language as the track
/// row above them, compact like the timeline's SE rows 窶・with the timeline
/// rows' controls: a lane chevron (twirl-down waveform strip) and the
/// waveform's eye toggle.
class _StoryboardSeLabel extends StatelessWidget {
  const _StoryboardSeLabel({
    required this.track,
    required this.slot,
    this.waveformVisible = true,
    this.onToggleWaveform,
    this.laneExpanded = false,
    this.onToggleLane,
    this.activeLayer,
    this.active = false,
    this.onSelectLayer,
    this.onToggleLayerVisibility,
    this.onToggleLayerMuted,
    this.onLayerOpacityChanged,
    this.onLayerMarkSelected,
    this.layerFxEnabledOf,
    this.onToggleLayerFx,
  });

  final Track track;
  final int slot;
  final bool waveformVisible;
  final VoidCallback? onToggleWaveform;
  final bool laneExpanded;
  final VoidCallback? onToggleLane;

  /// The ACTIVE cut's layer behind this slot (null while the active cut
  /// lives on another track or has no such slot) 窶・the timeline-parity
  /// controls act on it.
  final Layer? activeLayer;

  /// Whether this row's TRACK layer is the session's active layer — the
  /// same highlight the timeline row shows (W3 identity keeps them in
  /// sync automatically).
  final bool active;

  /// Tapping the row selects its track layer, like tapping a timeline
  /// row label. Null keeps the row display-only.
  final ValueChanged<LayerId>? onSelectLayer;
  final ValueChanged<LayerId>? onToggleLayerVisibility;
  final ValueChanged<LayerId>? onToggleLayerMuted;
  final void Function(LayerId layerId, double opacity)? onLayerOpacityChanged;
  final void Function(LayerId layerId, LayerMark mark)? onLayerMarkSelected;
  final bool Function(LayerId layerId)? layerFxEnabledOf;
  final ValueChanged<LayerId>? onToggleLayerFx;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final layer = activeLayer;
    final trackLayer = _trackSeAt(track, slot);
    final onSelect = onSelectLayer;
    // Rows stack FLUSH like the timeline rail 窶・no inter-row padding
    // (R7-竭､); the 1px borders carry the separation.
    return InkWell(
      key: ValueKey<String>(
        'storyboard-se-label-${track.id.value}-${slot + 1}',
      ),
      onTap: trackLayer == null || onSelect == null
          ? null
          : () => onSelect(trackLayer.id),
      child: Container(
        width: StoryboardPanel._trackLabelWidth,
        height: _seRowHeight,
        padding: const EdgeInsets.only(left: 2, right: 4),
        decoration: BoxDecoration(
          // The timeline row's active treatment verbatim (S-row selection,
          // W4): secondaryContainer fill + 2px secondary border.
          color: active
              ? colorScheme.secondaryContainer.withValues(alpha: 0.55)
              : colorScheme.surface,
          border: Border.all(
            color: active ? colorScheme.secondary : colorScheme.outlineVariant,
            width: active ? 2 : 1,
          ),
        ),
        child: Semantics(
          key: active
              ? const ValueKey<String>('storyboard-selected-layer')
              : null,
          label: active ? 'selected layer' : 'layer',
          container: true,
          explicitChildNodes: true,
          child: Row(
            children: [
              // The timeline rows' lane chevron, storyboard-prefixed.
              if (onToggleLane != null)
                InkWell(
                  key: ValueKey<String>(
                    'storyboard-se-lane-toggle-${track.id.value}-${slot + 1}',
                  ),
                  onTap: onToggleLane,
                  child: SizedBox(
                    width: 16,
                    height: _seRowHeight,
                    child: Icon(
                      laneExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                const SizedBox(width: 16),
              Icon(
                Icons.music_note_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                // The TRACK layer's stored name 窶・the same label the timeline
                // row shows (S1, S3, S2 insertion order survives; W3 ordering
                // unification).
                trackLayer?.name ?? 'S${slot + 1}',
                // Selection reads by COLOR only (user rule): no bold flip.
                style: TextStyle(
                  fontSize: 11,
                  color: active
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              // Timeline-parity controls on the ACTIVE cut's slot layer:
              // mark chip, fx (policy-gated), mute, eye and opacity 窶・the
              // same shared widgets/session hooks the timeline rows use.
              if (layer != null && onLayerMarkSelected != null)
                LayerMarkChip(
                  keyPrefix: 'storyboard',
                  layerId: layer.id,
                  mark: layer.mark,
                  onMarkSelected: onLayerMarkSelected!,
                ),
              const Spacer(),
              if (layer != null &&
                  onToggleLayerFx != null &&
                  layerKindShowsFxToggle(layer.kind))
                LayerFxToggleButton(
                  keyPrefix: 'storyboard',
                  layerId: layer.id,
                  fxEnabled: layerFxEnabledOf?.call(layer.id) ?? true,
                  onToggle: onToggleLayerFx!,
                ),
              if (layer != null && onToggleLayerMuted != null)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: IconButton(
                    key: ValueKey<String>('storyboard-layer-mute-${layer.id}'),
                    tooltip: layer.muted ? 'Unmute layer' : 'Mute layer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 20,
                      height: 20,
                    ),
                    icon: Icon(
                      layer.muted ? Icons.volume_off : Icons.volume_up,
                      size: 13,
                    ),
                    onPressed: () => onToggleLayerMuted!(layer.id),
                  ),
                ),
              if (layer != null && onToggleLayerVisibility != null)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: IconButton(
                    key: ValueKey<String>(
                      'storyboard-layer-visibility-${layer.id}',
                    ),
                    tooltip: layer.isVisible ? 'Hide layer' : 'Show layer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 20,
                      height: 20,
                    ),
                    icon: Icon(
                      layer.isVisible ? Icons.visibility : Icons.visibility_off,
                      size: 13,
                    ),
                    onPressed: () => onToggleLayerVisibility!(layer.id),
                  ),
                ),
              if (layer != null && onLayerOpacityChanged != null)
                SizedBox(
                  width: 44,
                  child: FieldSlider(
                    key: ValueKey<String>(
                      'storyboard-layer-opacity-${layer.id}',
                    ),
                    min: 0,
                    max: 1,
                    value: layer.opacity.clamp(0.0, 1.0).toDouble(),
                    valueText: '${(layer.opacity * 100).round()}%',
                    displayFactor: 100,
                    height: 16,
                    onChanged: (opacity) =>
                        onLayerOpacityChanged!(layer.id, opacity),
                  ),
                ),
              if (onToggleWaveform != null)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: IconButton(
                    key: ValueKey<String>(
                      'storyboard-se-waveform-toggle-'
                      '${track.id.value}-${slot + 1}',
                    ),
                    tooltip: waveformVisible
                        ? 'Hide Waveform'
                        : 'Show Waveform',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 20,
                      height: 20,
                    ),
                    icon: Icon(
                      waveformVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 13,
                      color: waveformVisible
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onToggleWaveform,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A twirled-down lane's rail label row (Audio / Opacity), indented under
/// its owner row like the timeline's lane labels.
class _StoryboardLaneLabel extends StatelessWidget {
  const _StoryboardLaneLabel({
    required this.laneKey,
    required this.label,
    required this.icon,
    required this.height,
  });

  final String laneKey;
  final String label;
  final IconData icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey<String>(laneKey),
      width: StoryboardPanel._trackLabelWidth,
      height: height,
      padding: const EdgeInsets.only(left: 18, right: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// One TRACK-owned SE row: the track's [slot]th SE layer rendered straight
/// on the global frame axis 窶・blocks keep their true lengths (a sound may
/// cross cut boundaries; each crossed boundary draws a `~` continuation
/// mark) and the timeline's data is exactly this layer, by identity.
class _StoryboardSeRow extends StatelessWidget {
  const _StoryboardSeRow({
    required this.trackIndex,
    required this.slot,
    required this.layer,
    required this.layoutEntries,
    required this.width,
    required this.timelineScale,
    required this.projectFps,
    this.audioPeaksFor,
    this.activeCutId,
    this.onSelectSeBlock,
    this.seCommaDrag,
  });

  final int trackIndex;
  final int slot;

  /// The track's GLOBAL SE layer behind this row (null = fewer rows).
  final Layer? layer;
  final List<StoryboardTimelineLayoutEntry> layoutEntries;
  final double width;
  final TimelineScale timelineScale;
  final int projectFps;
  final AudioPeaks? Function(String filePath)? audioPeaksFor;

  /// Timeline parity: SE blocks tap-select (any cut) and carry the comma
  /// edge grips on the ACTIVE cut (the session's exposure drags are
  /// active-cut scoped).
  final CutId? activeCutId;
  final void Function(CutId cutId, LayerId layerId, int blockStartFrame)?
  onSelectSeBlock;
  final TimelineCommaDragCallbacks? seCommaDrag;

  /// The layout entry whose cut window contains [globalFrame].
  StoryboardTimelineLayoutEntry? _entryContaining(int globalFrame) {
    for (final entry in layoutEntries) {
      if (globalFrame >= entry.startFrame && globalFrame < entry.endFrame) {
        return entry;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final spans = <Widget>[];
    final layer = this.layer;
    if (layer != null) {
      final blocks = drawingBlocks(layer.timeline);
      // Paper blocks first 窶・the storyboard SE row has no cells
      // underneath, so each block paints its own paper span (SePaperSpan)
      // at its TRUE global extent; waveforms go above the paper, the
      // writing on top.
      for (final block in blocks) {
        spans.add(
          Positioned(
            left: timelineScale.leftForFrame(block.startIndex),
            top: 0,
            bottom: 0,
            width:
                (block.endIndexExclusive - block.startIndex) *
                timelineScale.pixelsPerFrame,
            child: IgnorePointer(
              key: ValueKey<String>(
                'storyboard-se-paper-${layer.id}-${block.startIndex}',
              ),
              child: SePaperSpan(
                axis: Axis.horizontal,
                frameCellExtent: timelineScale.pixelsPerFrame,
              ),
            ),
          ),
        );
      }
      // Waveforms above the paper (painted UNDER the SE writing): sounds
      // are FRAME-LINKED 窶・each carrying block windows its waveform,
      // clamped to the block and the file length (cut ends no longer
      // clip 窶・the block may cross them).
      final audioPeaksFor = this.audioPeaksFor;
      if (audioPeaksFor != null) {
        for (final span in seAudioSpans(layer)) {
          final peaks = audioPeaksFor(span.clip.filePath);
          if (peaks == null) {
            continue;
          }
          // The offset trim shrinks the audible tail (same as the
          // timeline rows and playback).
          final endExclusive = math.min(
            span.startFrame +
                peaks.durationFrames(projectFps) -
                span.clip.offsetFrames,
            span.endFrameExclusive,
          );
          if (endExclusive <= span.startFrame) {
            continue;
          }
          spans.add(
            Positioned(
              left: timelineScale.leftForFrame(span.startFrame),
              top: 0,
              bottom: 0,
              width:
                  (endExclusive - span.startFrame) *
                  timelineScale.pixelsPerFrame,
              child: IgnorePointer(
                key: ValueKey<String>(
                  'storyboard-audio-clip-${layer.id}'
                  '-${span.clipIndex}-b${span.startFrame}',
                ),
                child: CustomPaint(
                  painter: WaveformPainter(
                    peaks: peaks,
                    fps: projectFps,
                    pixelsPerFrame: timelineScale.pixelsPerFrame,
                    // Ink on the paper spans, like the timeline SE rows.
                    color: timelineDrawingInkColor.withValues(alpha: 0.22),
                    leadingFrames: span.clip.offsetFrames,
                  ),
                ),
              ),
            ),
          );
        }
      }
      // The sheet's writing on the paper blocks.
      for (final block in blocks) {
        String? dialogue;
        String? seName;
        for (final frame in layer.frames) {
          if (frame.id == block.frameId) {
            dialogue = frame.name;
            seName = frame.seName;
            break;
          }
        }
        spans.add(
          Positioned(
            left: timelineScale.leftForFrame(block.startIndex),
            top: 0,
            bottom: 0,
            width:
                (block.endIndexExclusive - block.startIndex) *
                timelineScale.pixelsPerFrame,
            child: IgnorePointer(
              key: ValueKey<String>(
                'storyboard-se-span-${layer.id}-${block.startIndex}',
              ),
              child: SeSpanVisual(
                axis: Axis.horizontal,
                dialogue: dialogue ?? '',
                seName: seName,
              ),
            ),
          ),
        );
      }
      // A `~` continuation mark on every cut boundary a block crosses 窶・
      // the sound carries on into the next cut.
      for (final block in blocks) {
        for (final entry in layoutEntries) {
          final boundary = entry.startFrame;
          if (boundary <= block.startIndex ||
              boundary >= block.endIndexExclusive) {
            continue;
          }
          spans.add(
            Positioned(
              left: timelineScale.leftForFrame(boundary) - 7,
              top: 0,
              bottom: 0,
              width: 14,
              child: IgnorePointer(
                key: ValueKey<String>(
                  'storyboard-se-crossing-${layer.id}-$boundary',
                ),
                child: Center(
                  child: Text(
                    '~',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: timelineDrawingInkColor,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
      // Timeline parity: tap zones select the block (its OWNING cut +
      // layer + the block's cut-local start 窶・the session's contract)窶ｦ
      if (onSelectSeBlock != null) {
        for (final block in blocks) {
          final owner = _entryContaining(block.startIndex);
          if (owner == null) {
            continue;
          }
          spans.add(
            Positioned(
              left: timelineScale.leftForFrame(block.startIndex),
              top: 0,
              bottom: 0,
              width:
                  (block.endIndexExclusive - block.startIndex) *
                  timelineScale.pixelsPerFrame,
              child: GestureDetector(
                key: ValueKey<String>(
                  'storyboard-se-block-select-${layer.id}'
                  '-${block.startIndex}',
                ),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelectSeBlock!(
                  owner.cut.id,
                  layer.id,
                  block.startIndex - owner.startFrame,
                ),
              ),
            ),
          );
        }
      }
      // 窶ｦand the ACTIVE cut's blocks carry the timeline's own comma edge
      // grips (the SAME shared widget + session drag hooks; block starts
      // pass CUT-LOCAL 窶・the session converts to the global axis). A
      // block spilling in from an earlier cut keeps only its END grip
      // here (its start belongs to that cut).
      final seCommaDrag = this.seCommaDrag;
      if (seCommaDrag != null && activeCutId != null) {
        StoryboardTimelineLayoutEntry? activeEntry;
        for (final entry in layoutEntries) {
          if (entry.cut.id == activeCutId) {
            activeEntry = entry;
            break;
          }
        }
        if (activeEntry != null) {
          var ordinal = 0;
          for (final block in blocks) {
            final blockOrdinal = ordinal;
            ordinal += 1;
            final startsHere =
                block.startIndex >= activeEntry.startFrame &&
                block.startIndex < activeEntry.endFrame;
            final spillsIn =
                block.startIndex < activeEntry.startFrame &&
                block.endIndexExclusive > activeEntry.startFrame;
            if (!startsHere && !spillsIn) {
              continue;
            }
            final localStart = startsHere
                ? block.startIndex - activeEntry.startFrame
                : 0;
            final startOffset = timelineScale.leftForFrame(
              math.max(block.startIndex, activeEntry.startFrame),
            );
            final endOffset = timelineScale.leftForFrame(
              block.endIndexExclusive,
            );
            for (final edge in TimelineBlockEdge.values) {
              if (edge == TimelineBlockEdge.start && spillsIn) {
                continue;
              }
              spans.add(
                TimelineBlockEdgeGrip(
                  key: ValueKey<String>(
                    'storyboard-se-grip-${layer.id}-$blockOrdinal'
                    '-${edge.name}',
                  ),
                  layerId: layer.id,
                  blockStartIndex: localStart,
                  blockOrdinal: blockOrdinal,
                  edge: edge,
                  blockStartOffset: startOffset,
                  blockEndOffset: endOffset,
                  frameCellExtent: timelineScale.pixelsPerFrame,
                  crossAxisExtent: _seRowHeight,
                  callbacks: seCommaDrag,
                ),
              );
            }
          }
        }
      }
    }

    return SizedBox(
      key: ValueKey<String>('storyboard-se-row-$trackIndex-${slot + 1}'),
      width: width,
      height: _seRowHeight,
      child: Stack(children: spans),
    );
  }
}

/// The twirled-down S row's enlarged waveform strip: the timeline Audio
/// lane ITSELF, mounted ONCE across the whole track (the layer is
/// track-owned 窶・its spans sit on the global axis and slide-edit
/// everywhere; the session's clip edits resolve by layer id).
class _StoryboardAudioLaneRow extends StatelessWidget {
  const _StoryboardAudioLaneRow({
    required this.trackIndex,
    required this.slot,
    required this.layer,
    required this.layoutEntries,
    required this.width,
    required this.timelineScale,
    required this.projectFps,
    this.audioPeaksFor,
    this.activeCutId,
    this.onSetAudioClipOffset,
  });

  final int trackIndex;
  final int slot;

  /// The track's GLOBAL SE layer behind this lane.
  final Layer? layer;
  final List<StoryboardTimelineLayoutEntry> layoutEntries;
  final double width;
  final TimelineScale timelineScale;
  final int projectFps;
  final AudioPeaks? Function(String filePath)? audioPeaksFor;
  final CutId? activeCutId;
  final void Function(LayerId layerId, int clipIndex, int offsetFrames)?
  onSetAudioClipOffset;

  @override
  Widget build(BuildContext context) {
    final spans = <Widget>[];
    final onSetAudioClipOffset = this.onSetAudioClipOffset;
    final layer = this.layer;
    // The reused lane renders with timeline metrics: the frame-axis zoom is
    // the storyboard's pixels-per-frame, the cross extent this lane's
    // height.
    final laneMetrics = TimelineGridMetrics(
      frameCellWidth: timelineScale.pixelsPerFrame,
      layerRowHeight: _audioLaneHeight - 2,
    );
    if (layer != null && layoutEntries.isNotEmpty) {
      final totalFrames = layoutEntries.last.endFrame;
      spans.add(
        Positioned(
          left: timelineScale.leftForFrame(0),
          top: 1,
          width: totalFrames * timelineScale.pixelsPerFrame,
          height: _audioLaneHeight - 2,
          child: KeyedSubtree(
            key: ValueKey<String>('storyboard-audio-lane-span-${layer.id}'),
            child: SeAudioLaneFrameRow(
              layer: layer,
              frameStartIndex: 0,
              frameEndIndexExclusive: totalFrames,
              leadingFrameSpacerWidth: 0,
              trailingFrameSpacerWidth: 0,
              metrics: laneMetrics,
              fps: projectFps,
              audioPeaksFor: audioPeaksFor,
              keyPrefix: 'storyboard-${layer.id}',
              onSetClipOffset: onSetAudioClipOffset == null
                  ? null
                  : (clipIndex, offsetFrames) =>
                        onSetAudioClipOffset(layer.id, clipIndex, offsetFrames),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      key: ValueKey<String>(
        'storyboard-audio-lane-row-$trackIndex-${slot + 1}',
      ),
      width: width,
      height: _audioLaneHeight,
      child: Stack(children: spans),
    );
  }
}

/// One Transform lane's frame band: the reused timeline lane substrate
/// rendered PER CUT (the audio lane's remount pattern 窶・each span runs
/// cut-local frames at the cut's global left). Key markers ride each
/// cut's own transform track; editing is gated to the ACTIVE cut, like
/// the audio lane's slide edit.
class _StoryboardLaneStripRow extends StatelessWidget {
  const _StoryboardLaneStripRow({
    required this.rowKey,
    required this.layoutEntries,
    required this.width,
    required this.timelineScale,
    required this.laneOf,
    this.activeCutId,
    this.laneEditFor,
  });

  final String rowKey;
  final List<StoryboardTimelineLayoutEntry> layoutEntries;
  final double width;
  final TimelineScale timelineScale;

  /// Resolves one cut's (carrier layer, lane) pair; null skips the cut
  /// (an S slot the cut doesn't carry).
  final (Layer, PropertyLaneRow)? Function(Cut cut) laneOf;
  final CutId? activeCutId;
  final PropertyLaneEditCallbacks? Function(Cut cut)? laneEditFor;

  @override
  Widget build(BuildContext context) {
    final metrics = TimelineGridMetrics(
      frameCellWidth: timelineScale.pixelsPerFrame,
      layerRowHeight: _transformLaneHeight - 2,
    );
    final spans = <Widget>[];
    for (final entry in layoutEntries) {
      final resolved = laneOf(entry.cut);
      if (resolved == null) {
        continue;
      }
      final (carrier, lane) = resolved;
      spans.add(
        Positioned(
          left: timelineScale.leftForFrame(entry.startFrame),
          top: 1,
          width: entry.duration * timelineScale.pixelsPerFrame,
          height: _transformLaneHeight - 2,
          child: KeyedSubtree(
            key: ValueKey<String>('$rowKey-span-${entry.cut.id.value}'),
            child: TimelineLaneFrameRow(
              layer: carrier,
              lane: lane,
              frameStartIndex: 0,
              frameEndIndexExclusive: entry.duration,
              leadingFrameSpacerWidth: 0,
              trailingFrameSpacerWidth: 0,
              metrics: metrics,
              laneEdit: entry.cut.id == activeCutId
                  ? laneEditFor?.call(entry.cut)
                  : null,
              keyPrefix: 'storyboard',
            ),
          ),
        ),
      );
    }
    return SizedBox(
      key: ValueKey<String>(rowKey),
      width: width,
      height: _transformLaneHeight,
      child: Stack(children: spans),
    );
  }
}

/// The twirled-down V track's Opacity lane: one fade-envelope span per cut
/// with draggable fade in/out handles at the span edges 窶・the cut fade
/// ("opacity joins the transform system"). Commits ONE undo per handle
/// drag via [StoryboardPanel.onSetCutFade].
class _StoryboardOpacityLaneRow extends StatelessWidget {
  const _StoryboardOpacityLaneRow({
    required this.trackIndex,
    required this.layoutEntries,
    required this.width,
    required this.timelineScale,
    this.onSetCutFade,
    this.onSetCutFadeTarget,
  });

  final int trackIndex;
  final List<StoryboardTimelineLayoutEntry> layoutEntries;
  final double width;
  final TimelineScale timelineScale;
  final void Function(CutId cutId, int fadeInFrames, int fadeOutFrames)?
  onSetCutFade;
  final void Function(CutId cutId, CutFadeTarget fadeTarget)?
  onSetCutFadeTarget;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey<String>('storyboard-opacity-lane-row-$trackIndex'),
      width: width,
      height: _opacityLaneHeight,
      child: Stack(
        children: [
          for (final entry in layoutEntries)
            Positioned(
              left: timelineScale.leftForFrame(entry.startFrame),
              top: 1,
              bottom: 1,
              width: entry.duration * timelineScale.pixelsPerFrame,
              child: _CutFadeSpan(
                key: ValueKey<String>(
                  'storyboard-cut-fade-span-${entry.cut.id.value}',
                ),
                cut: entry.cut,
                frameCellExtent: timelineScale.pixelsPerFrame,
                onSetFade: onSetCutFade == null
                    ? null
                    : (fadeIn, fadeOut) =>
                          onSetCutFade!(entry.cut.id, fadeIn, fadeOut),
                onSetFadeTarget: onSetCutFadeTarget == null
                    ? null
                    : (target) => onSetCutFadeTarget!(entry.cut.id, target),
              ),
            ),
        ],
      ),
    );
  }
}

/// One cut's fade-envelope span. The opacity envelope paints from the
/// cut's own lane (any key shape), while dragging an EDGE ZONE previews
/// and commits the canonical fade shape for that end.
class _CutFadeSpan extends StatefulWidget {
  const _CutFadeSpan({
    super.key,
    required this.cut,
    required this.frameCellExtent,
    this.onSetFade,
    this.onSetFadeTarget,
  });

  final Cut cut;
  final double frameCellExtent;
  final void Function(int fadeInFrames, int fadeOutFrames)? onSetFade;

  /// Sets what the fade fades TO (FO=black / WO=white) 窶・the span's
  /// right-click/long-press menu. Null hides the menu.
  final ValueChanged<CutFadeTarget>? onSetFadeTarget;

  @override
  State<_CutFadeSpan> createState() => _CutFadeSpanState();
}

class _CutFadeSpanState extends State<_CutFadeSpan> {
  static const double _handleExtent = 14;

  double _dragDelta = 0;
  bool _dragging = false;
  bool _draggingOut = false;

  int get _deltaFrames => (_dragDelta / widget.frameCellExtent).round();

  int get _maxFade => math.max(0, widget.cut.duration - 1);

  int get _previewFadeIn {
    final base = cutFadeLengths(widget.cut).fadeInFrames;
    if (!_dragging || _draggingOut) {
      return base;
    }
    return (base + _deltaFrames).clamp(0, _maxFade);
  }

  int get _previewFadeOut {
    final base = cutFadeLengths(widget.cut).fadeOutFrames;
    if (!_dragging || !_draggingOut) {
      return base;
    }
    return (base - _deltaFrames).clamp(0, _maxFade);
  }

  void _endDrag() {
    final fadeIn = _previewFadeIn;
    final fadeOut = _previewFadeOut;
    final base = cutFadeLengths(widget.cut);
    setState(() {
      _dragging = false;
      _dragDelta = 0;
    });
    if (fadeIn != base.fadeInFrames || fadeOut != base.fadeOutFrames) {
      widget.onSetFade?.call(fadeIn, fadeOut);
    }
  }

  /// Per-frame opacity samples: the cut's own lane at rest, the canonical
  /// preview shape while a handle drags.
  List<double> _envelopeSamples() {
    final duration = math.max(1, widget.cut.duration);
    if (!_dragging) {
      return [
        for (var frame = 0; frame < duration; frame += 1)
          widget.cut.fadeOpacityAt(frame),
      ];
    }
    final fadeIn = _previewFadeIn;
    final fadeOut = _previewFadeOut;
    final last = duration - 1;
    return [
      for (var frame = 0; frame < duration; frame += 1)
        math.min(
          fadeIn > 0 && frame < fadeIn ? frame / fadeIn : 1.0,
          fadeOut > 0 && frame > last - fadeOut
              ? (last - frame) / fadeOut
              : 1.0,
        ),
    ];
  }

  Widget _handleZone({required bool trailing}) {
    return Positioned(
      left: trailing ? null : 0,
      right: trailing ? 0 : null,
      top: 0,
      bottom: 0,
      width: _handleExtent,
      child: Tooltip(
        message: trailing ? 'Fade Out' : 'Fade In',
        waitDuration: const Duration(milliseconds: 600),
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            key: ValueKey<String>(
              'storyboard-cut-fade-${trailing ? 'out' : 'in'}-handle-'
              '${widget.cut.id.value}',
            ),
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (_) => setState(() {
              _dragging = true;
              _draggingOut = trailing;
              _dragDelta = 0;
            }),
            onHorizontalDragUpdate: (details) =>
                setState(() => _dragDelta += details.delta.dx),
            onHorizontalDragEnd: (_) => _endDrag(),
            onHorizontalDragCancel: () => setState(() {
              _dragging = false;
              _dragDelta = 0;
            }),
          ),
        ),
      ),
    );
  }

  Future<void> _showFadeTargetMenu(Offset globalPosition) async {
    final onSetFadeTarget = widget.onSetFadeTarget;
    if (onSetFadeTarget == null) {
      return;
    }
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final current = widget.cut.metadata.fadeTarget;
    final selected = await showMenu<CutFadeTarget>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final target in CutFadeTarget.values)
          CheckedPopupMenuItem<CutFadeTarget>(
            key: ValueKey<String>('cut-fade-target-${target.name}'),
            value: target,
            checked: target == current,
            child: Text(
              target == CutFadeTarget.black
                  ? 'Fade to Black (FO)'
                  : 'Fade to White (WO)',
            ),
          ),
      ],
    );
    if (selected != null && selected != current) {
      onSetFadeTarget(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final editable = widget.onSetFade != null && widget.cut.duration > 1;
    final fadeIn = _previewFadeIn;
    final fadeOut = _previewFadeOut;
    // The envelope tints toward the fade TARGET so a white fade reads at a
    // glance (FO=accent as before, WO=near-white line).
    final fadeToWhite = widget.cut.metadata.fadeTarget == CutFadeTarget.white;
    final envelopeColor = fadeToWhite
        ? const Color(0xFFE8E6E1)
        : AppColors.accent;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          // Right-click/long-press: the fade-target menu (FO/WO).
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapUp: widget.onSetFadeTarget == null
                ? null
                : (details) => _showFadeTargetMenu(details.globalPosition),
            onLongPressStart: widget.onSetFadeTarget == null
                ? null
                : (details) => _showFadeTargetMenu(details.globalPosition),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
                borderRadius: const BorderRadius.all(Radius.circular(3)),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: CustomPaint(
                painter: _CutFadeEnvelopePainter(
                  samples: _envelopeSamples(),
                  pixelsPerFrame: widget.frameCellExtent,
                  lineColor: envelopeColor,
                  fillColor: envelopeColor.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
        ),
        if (editable) _handleZone(trailing: false),
        if (editable) _handleZone(trailing: true),
        if (_dragging)
          Positioned(
            left: 4,
            top: 1,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  child: Text(
                    _draggingOut ? 'out ${fadeOut}f' : 'in ${fadeIn}f',
                    style: const TextStyle(fontSize: 9, color: Colors.black),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Paints a cut's opacity envelope: a line through per-frame samples with
/// the area underneath filled 窶・1.0 rides the top edge, 0.0 the bottom.
class _CutFadeEnvelopePainter extends CustomPainter {
  const _CutFadeEnvelopePainter({
    required this.samples,
    required this.pixelsPerFrame,
    required this.lineColor,
    required this.fillColor,
  });

  final List<double> samples;
  final double pixelsPerFrame;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.isEmpty) {
      return;
    }
    const inset = 2.0;
    final usable = size.height - inset * 2;
    double yFor(double value) => inset + (1 - value.clamp(0.0, 1.0)) * usable;

    final line = Path()..moveTo(0, yFor(samples.first));
    for (var frame = 0; frame < samples.length; frame += 1) {
      // Each frame holds its value across its own cell.
      final left = frame * pixelsPerFrame;
      final right = math.min(size.width, left + pixelsPerFrame);
      final y = yFor(samples[frame]);
      line.lineTo(left, y);
      line.lineTo(right, y);
      if (right >= size.width) {
        break;
      }
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = fillColor);
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(covariant _CutFadeEnvelopePainter oldDelegate) {
    if (oldDelegate.pixelsPerFrame != pixelsPerFrame ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.samples.length != samples.length) {
      return true;
    }
    for (var index = 0; index < samples.length; index += 1) {
      if (oldDelegate.samples[index] != samples[index]) {
        return true;
      }
    }
    return false;
  }
}

/// Rail rows share the timeline label rail's row language 窶・bordered
/// surface rows, a kind icon leading the name 窶・so the storyboard's left
/// edge reads near-identically to the timeline's layers/sections rail
/// (user direction). The track row opens its section like the timeline's
/// heavier section divider.
class _StoryboardTrackLabel extends StatelessWidget {
  const _StoryboardTrackLabel({
    required this.track,
    required this.trackLabel,
    this.laneExpanded = false,
    this.onToggleLane,
    this.activeCut,
    this.cutFxEnabledOf,
    this.onToggleCutFx,
    this.cutPictureVisibleOf,
    this.onToggleCutPictureVisibility,
  });

  final Track track;
  final String trackLabel;
  final bool laneExpanded;
  final VoidCallback? onToggleLane;

  /// The ACTIVE cut when it lives on this track (null otherwise) 窶・the
  /// V-row display toggles act on it, standing down like the S rows'
  /// layer controls when the active cut lives elsewhere.
  final Cut? activeCut;
  final bool Function(CutId cutId)? cutFxEnabledOf;
  final ValueChanged<CutId>? onToggleCutFx;
  final bool Function(CutId cutId)? cutPictureVisibleOf;
  final ValueChanged<CutId>? onToggleCutPictureVisibility;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey<String>('storyboard-track-label-row-${track.id.value}'),
      width: StoryboardPanel._trackLabelWidth,
      height: StoryboardPanel._trackLaneHeight,
      padding: const EdgeInsets.only(left: 2, right: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // The timeline rows' lane chevron: twirls down the track's
          // cut-level Transform group (the V-track lanes + fade strip).
          if (onToggleLane != null)
            InkWell(
              key: ValueKey<String>(
                'storyboard-track-lane-toggle-${track.id.value}',
              ),
              onTap: onToggleLane,
              child: SizedBox(
                width: 16,
                height: 24,
                child: Icon(
                  laneExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            const SizedBox(width: 16),
          const Icon(Icons.movie_outlined, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trackLabel,
                  key: ValueKey<String>(
                    'storyboard-track-label-${track.id.value}',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (track.name.isNotEmpty)
                  Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          // V-row display toggles on the ACTIVE cut (R9), in the S rows'
          // visual language: the fx switch bypasses the cut-level
          // Transform group (pose + fade) in the playback display, the
          // eye hides the cut's picture there.
          if (activeCut != null && onToggleCutFx != null)
            _CutFxToggleButton(
              cutId: activeCut!.id,
              fxEnabled: cutFxEnabledOf?.call(activeCut!.id) ?? true,
              onToggle: onToggleCutFx!,
            ),
          if (activeCut != null && onToggleCutPictureVisibility != null)
            SizedBox(
              width: 20,
              height: 20,
              child: IconButton(
                key: ValueKey<String>(
                  'storyboard-cut-visibility-${activeCut!.id.value}',
                ),
                tooltip: (cutPictureVisibleOf?.call(activeCut!.id) ?? true)
                    ? 'Hide cut picture'
                    : 'Show cut picture',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 20,
                  height: 20,
                ),
                icon: Icon(
                  (cutPictureVisibleOf?.call(activeCut!.id) ?? true)
                      ? Icons.visibility
                      : Icons.visibility_off,
                  size: 13,
                ),
                onPressed: () => onToggleCutPictureVisibility!(activeCut!.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// The V-row fx switch 窶・[LayerFxToggleButton]'s exact look, cut-typed
/// (the shared widget speaks LayerId; the key and callback are the only
/// differences).
class _CutFxToggleButton extends StatelessWidget {
  const _CutFxToggleButton({
    required this.cutId,
    required this.fxEnabled,
    required this.onToggle,
  });

  final CutId cutId;
  final bool fxEnabled;
  final ValueChanged<CutId> onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Tight SizedBox: the M3 IconButton otherwise inflates to the 48px
    // minimum tap target and overflows the row (shared gotcha).
    return SizedBox(
      width: 26,
      height: 26,
      child: IconButton(
        key: ValueKey<String>('storyboard-cut-fx-${cutId.value}'),
        tooltip: fxEnabled ? 'Bypass cut FX' : 'Apply cut FX',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 26, height: 26),
        icon: Text(
          'fx',
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w700,
            color: fxEnabled
                ? AppColors.accent
                : colorScheme.onSurface.withValues(alpha: 0.35),
          ),
        ),
        onPressed: () => onToggle(cutId),
      ),
    );
  }
}

class _StoryboardTrackRow extends StatelessWidget {
  const _StoryboardTrackRow({
    required this.track,
    required this.layoutEntries,
    required this.activeCutId,
    required this.onCutSelected,
    required this.onCutReordered,
    required this.cutTrim,
    required this.cutMove,
    required this.thumbnailFor,
    required this.timelineScale,
    required this.showSeconds,
    required this.projectFps,
  });

  final Track track;
  final List<StoryboardTimelineLayoutEntry> layoutEntries;
  final CutId activeCutId;
  final ValueChanged<CutId> onCutSelected;
  final CutReorderedCallback? onCutReordered;
  final StoryboardCutTrimCallbacks? cutTrim;
  final StoryboardCutMoveCallbacks? cutMove;
  final ui.Image? Function(Cut cut)? thumbnailFor;
  final TimelineScale timelineScale;
  final bool showSeconds;
  final int projectFps;

  String _totalLabelFor(StoryboardTimelineLayoutEntry entry) {
    return showSeconds
        ? timelineSecondsLabel(entry.endFrame, projectFps)
        : '${entry.endFrame}f';
  }

  @override
  Widget build(BuildContext context) {
    final timelineWidth = _timelineWidthFor(layoutEntries, timelineScale);

    return KeyedSubtree(
      key: ValueKey<String>('storyboard-track-row-${track.id.value}'),
      child: SizedBox(
        key: ValueKey<String>(
          'storyboard-track-timeline-area-${track.id.value}',
        ),
        width: timelineWidth,
        height: StoryboardPanel._trackLaneHeight,
        child: Stack(
          children: [
            for (final entry in layoutEntries)
              Positioned(
                key: ValueKey<String>(
                  'storyboard-cut-positioned-${entry.cutId.value}',
                ),
                left: timelineScale.leftForFrame(entry.startFrame),
                width: timelineScale.widthForDuration(entry.duration),
                top: 0,
                bottom: 0,
                child: _ReorderableStoryboardCutBlock(
                  layoutEntry: entry,
                  width: timelineScale.widthForDuration(entry.duration),
                  isActive: entry.cutId == activeCutId,
                  onSelected: onCutSelected,
                  canReorder:
                      onCutReordered != null && layoutEntries.length > 1,
                  onCutReordered: onCutReordered,
                  cutMove: cutMove,
                  pixelsPerFrame: timelineScale.pixelsPerFrame,
                  totalLabel: _totalLabelFor(entry),
                  thumbnail: thumbnailFor?.call(entry.cut),
                  showThumbnail: thumbnailFor != null,
                ),
              ),
            // Trim grips paint over the block edges (their 12px strips win
            // pointer contests there; block taps/reorder keep the middle).
            // The start grip SLIDES the cut (gap authoring) — every cut has
            // one, the first included.
            if (cutTrim != null)
              for (final entry in layoutEntries) ...[
                _StoryboardCutEdgeGrip(
                  cutId: entry.cutId,
                  cutOrdinal: entry.cutIndex,
                  edge: TimelineBlockEdge.start,
                  blockStartOffset: timelineScale.leftForFrame(
                    entry.startFrame,
                  ),
                  blockEndOffset:
                      timelineScale.leftForFrame(entry.startFrame) +
                      timelineScale.widthForDuration(entry.duration),
                  frameCellExtent: timelineScale.pixelsPerFrame,
                  crossAxisExtent: StoryboardPanel._trackLaneHeight,
                  callbacks: cutTrim!,
                ),
                _StoryboardCutEdgeGrip(
                  cutId: entry.cutId,
                  cutOrdinal: entry.cutIndex,
                  edge: TimelineBlockEdge.end,
                  blockStartOffset: timelineScale.leftForFrame(
                    entry.startFrame,
                  ),
                  blockEndOffset:
                      timelineScale.leftForFrame(entry.startFrame) +
                      timelineScale.widthForDuration(entry.duration),
                  frameCellExtent: timelineScale.pixelsPerFrame,
                  crossAxisExtent: StoryboardPanel._trackLaneHeight,
                  callbacks: cutTrim!,
                ),
              ],
          ],
        ),
      ),
    );
  }

  double _timelineWidthFor(
    List<StoryboardTimelineLayoutEntry> entries,
    TimelineScale scale,
  ) {
    const trailingPadding = 12.0;

    if (entries.isEmpty) {
      return 0;
    }

    return entries
            .map(
              (entry) =>
                  scale.leftForFrame(entry.startFrame) +
                  scale.widthForDuration(entry.duration),
            )
            .reduce(
              (width, nextWidth) => width > nextWidth ? width : nextWidth,
            ) +
        trailingPadding;
  }
}

/// Vertical frame-boundary lines behind the cut blocks (the timeline grid's
/// cell borders, storyboard-flavored): every frame when cells are wide,
/// thinning to the shared label cadence when zoomed out.
class _StoryboardFrameLinesPainter extends CustomPainter {
  const _StoryboardFrameLinesPainter({
    required this.pixelsPerFrame,
    required this.color,
  });

  final double pixelsPerFrame;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (pixelsPerFrame <= 0) {
      return;
    }
    final lineEveryFrames = pixelsPerFrame >= 16
        ? 1
        : TimelineGridMetrics(
            frameCellWidth: pixelsPerFrame,
          ).frameLabelEveryFrames;
    final step = pixelsPerFrame * lineEveryFrames;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_StoryboardFrameLinesPainter oldDelegate) {
    return oldDelegate.pixelsPerFrame != pixelsPerFrame ||
        oldDelegate.color != color;
  }
}

/// One cut trim grip: an inset vertical bar just inside a cut block's start
/// or end edge, mirroring the timeline's [TimelineBlockEdgeGrip] visuals and
/// gesture state machine (cumulative whole-frame deltas via the shared
/// comma-drag policy; the session recomputes the preview from its drag-start
/// snapshot).
///
/// The Positioned key derives from the cut ORDINAL, never its start frame 窶・
/// a roll drag moves the start every step, and a key change there would
/// rebuild the gesture subtree mid-drag and kill it (same constraint as the
/// timeline grips).
class _StoryboardCutEdgeGrip extends StatefulWidget {
  const _StoryboardCutEdgeGrip({
    required this.cutId,
    required this.cutOrdinal,
    required this.edge,
    required this.blockStartOffset,
    required this.blockEndOffset,
    required this.frameCellExtent,
    required this.crossAxisExtent,
    required this.callbacks,
  });

  final CutId cutId;
  final int cutOrdinal;
  final TimelineBlockEdge edge;
  final double blockStartOffset;
  final double blockEndOffset;
  final double frameCellExtent;
  final double crossAxisExtent;
  final StoryboardCutTrimCallbacks callbacks;

  static const double hitExtent = 12;
  static const double _barThickness = 3.5;
  static const double _barInset = 2.5;

  @override
  State<_StoryboardCutEdgeGrip> createState() => _StoryboardCutEdgeGripState();
}

class _StoryboardCutEdgeGripState extends State<_StoryboardCutEdgeGrip> {
  double _accumulatedDelta = 0;
  int _lastReportedFrames = 0;
  bool _dragging = false;

  void _startDrag() {
    if (!widget.callbacks.onBegin(widget.cutId, widget.edge)) {
      return;
    }
    setState(() {
      _dragging = true;
      _accumulatedDelta = 0;
      _lastReportedFrames = 0;
    });
  }

  void _updateDrag(double delta) {
    if (!_dragging) {
      return;
    }
    _accumulatedDelta += delta;
    final frames = commaDragFrameDelta(
      accumulatedDelta: _accumulatedDelta,
      frameCellExtent: widget.frameCellExtent,
    );
    if (frames == _lastReportedFrames) {
      return;
    }
    _lastReportedFrames = frames;
    widget.callbacks.onUpdate(frames);
  }

  void _endDrag() {
    if (!_dragging) {
      return;
    }
    setState(() => _dragging = false);
    widget.callbacks.onEnd();
  }

  void _cancelDrag() {
    if (!_dragging) {
      return;
    }
    setState(() => _dragging = false);
    widget.callbacks.onCancel();
  }

  @override
  void dispose() {
    // A grip can unmount mid-drag; commit rather than leak an open session
    // (same policy as the timeline grips).
    if (_dragging) {
      widget.callbacks.onEnd();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStartEdge = widget.edge == TimelineBlockEdge.start;
    final hitStart = isStartEdge
        ? widget.blockStartOffset
        : widget.blockEndOffset - _StoryboardCutEdgeGrip.hitExtent;
    final barColor = _dragging
        ? timelineSelectedFrameBorderColor
        : timelineDrawingInkColor.withValues(alpha: 0.38);

    return Positioned(
      key: ValueKey<String>(
        'storyboard-cut-edge-grip-${widget.edge.name}-${widget.cutOrdinal}',
      ),
      left: hitStart,
      top: 0,
      width: _StoryboardCutEdgeGrip.hitExtent,
      height: widget.crossAxisExtent,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _startDrag(),
          onHorizontalDragUpdate: (details) => _updateDrag(details.delta.dx),
          onHorizontalDragEnd: (_) => _endDrag(),
          onHorizontalDragCancel: _cancelDrag,
          child: Align(
            alignment: isStartEdge
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(
                left: isStartEdge ? _StoryboardCutEdgeGrip._barInset : 0,
                right: isStartEdge ? 0 : _StoryboardCutEdgeGrip._barInset,
              ),
              child: Container(
                width: _StoryboardCutEdgeGrip._barThickness,
                height: widget.crossAxisExtent * 0.55,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The drag layer around a cut block: mirrors the top-bar chips' semantics
/// (drop on a target block = same-track reorder to its index) so both
/// surfaces stay interchangeable.
class _ReorderableStoryboardCutBlock extends StatefulWidget {
  const _ReorderableStoryboardCutBlock({
    required this.layoutEntry,
    required this.width,
    required this.isActive,
    required this.onSelected,
    required this.canReorder,
    required this.onCutReordered,
    required this.cutMove,
    required this.pixelsPerFrame,
    required this.totalLabel,
    required this.thumbnail,
    required this.showThumbnail,
  });

  final StoryboardTimelineLayoutEntry layoutEntry;
  final double width;
  final bool isActive;
  final ValueChanged<CutId> onSelected;
  final bool canReorder;
  final CutReorderedCallback? onCutReordered;
  final StoryboardCutMoveCallbacks? cutMove;
  final double pixelsPerFrame;
  final String totalLabel;
  final ui.Image? thumbnail;
  final bool showThumbnail;

  @override
  State<_ReorderableStoryboardCutBlock> createState() =>
      _ReorderableStoryboardCutBlockState();
}

class _ReorderableStoryboardCutBlockState
    extends State<_ReorderableStoryboardCutBlock> {
  // Whole-block slide (R10-④): cumulative pointer dx → whole frames.
  double _moveDx = 0;
  bool _moving = false;

  StoryboardTimelineLayoutEntry get layoutEntry => widget.layoutEntry;

  void _handleMoveStart(DragStartDetails details) {
    final cutMove = widget.cutMove;
    if (cutMove == null || !cutMove.onBegin(layoutEntry.cutId)) {
      return;
    }
    _moving = true;
    _moveDx = 0;
  }

  void _handleMoveUpdate(DragUpdateDetails details) {
    if (!_moving) {
      return;
    }
    _moveDx += details.delta.dx;
    widget.cutMove!.onUpdate((_moveDx / widget.pixelsPerFrame).round());
  }

  void _handleMoveEnd(DragEndDetails details) {
    if (!_moving) {
      return;
    }
    _moving = false;
    widget.cutMove!.onEnd();
  }

  void _handleMoveCancel() {
    if (!_moving) {
      return;
    }
    _moving = false;
    widget.cutMove!.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    Widget block = _StoryboardCutBlock(
      layoutEntry: layoutEntry,
      width: widget.width,
      isActive: widget.isActive,
      onSelected: widget.onSelected,
      totalLabel: widget.totalLabel,
      thumbnail: widget.thumbnail,
      showThumbnail: widget.showThumbnail,
    );
    // A horizontal drag on the block's BODY slides the cut along the
    // frame axis (timeline block language, R10-④): live preview through
    // the session channel, one undo on release. Taps still select; the
    // long-press lift below owns reordering.
    if (widget.cutMove != null) {
      block = GestureDetector(
        key: ValueKey<String>('storyboard-cut-move-${layoutEntry.cutId.value}'),
        behavior: HitTestBehavior.translucent,
        // Pixel-exact deltas from the true pointer-down (the camera
        // overlay's rule) — touch slop must not eat the first frames.
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: _handleMoveStart,
        onHorizontalDragUpdate: _handleMoveUpdate,
        onHorizontalDragEnd: _handleMoveEnd,
        onHorizontalDragCancel: _handleMoveCancel,
        child: block,
      );
    }
    if (!widget.canReorder) {
      return block;
    }

    return DragTarget<CutId>(
      onWillAcceptWithDetails: (details) => details.data != layoutEntry.cutId,
      onAcceptWithDetails: (details) {
        if (details.data == layoutEntry.cutId) {
          return;
        }

        widget.onCutReordered?.call(
          draggedCutId: details.data,
          targetTrackId: layoutEntry.trackId,
          targetCutIndex: layoutEntry.cutIndex,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        // Long-press LIFTS the block for reordering (R10-④ moved the
        // plain horizontal drag to the slide); works with mouse-hold and
        // touch alike.
        return LongPressDraggable<CutId>(
          key: ValueKey<String>(
            'storyboard-cut-draggable-${layoutEntry.cutId.value}',
          ),
          data: layoutEntry.cutId,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.85,
              child: SizedBox(
                width: widget.width,
                height: StoryboardPanel._trackLaneHeight,
                child: _StoryboardCutBlock(
                  layoutEntry: layoutEntry,
                  width: widget.width,
                  isActive: widget.isActive,
                  onSelected: (_) {},
                  totalLabel: widget.totalLabel,
                  thumbnail: widget.thumbnail,
                  showThumbnail: widget.showThumbnail,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.45, child: block),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: isDropTarget
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: block,
          ),
        );
      },
    );
  }
}

class _StoryboardCutBlock extends StatelessWidget {
  const _StoryboardCutBlock({
    required this.layoutEntry,
    required this.width,
    required this.isActive,
    required this.onSelected,
    required this.totalLabel,
    this.thumbnail,
    this.showThumbnail = false,
  });

  final StoryboardTimelineLayoutEntry layoutEntry;
  final double width;
  final bool isActive;
  final ValueChanged<CutId> onSelected;

  /// Cumulative time at this cut's end (conte-sheet TIME column), rendered
  /// bottom-right; frames or seconds per the shared display toggle.
  final String totalLabel;

  /// Painted, never disposed here: the thumbnail store owns the image.
  final ui.Image? thumbnail;
  final bool showThumbnail;

  /// A translucent strip behind the overlay texts keeps them readable over
  /// the picture.
  Widget _scrim(BuildContext context, Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(3),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cut = layoutEntry.cut;
    final storyboardLayer = storyboardLayerForCut(cut);

    return TimelineBlock(
      key: ValueKey<String>('storyboard-cut-block-${cut.id.value}'),
      width: width,
      isActive: isActive,
      minHeight: 0,
      padding: const EdgeInsets.all(4),
      onTap: isActive ? null : () => onSelected(cut.id),
      // Conte-sheet cell turned sideways: the camera-view picture fills the
      // block center, texts stack on top of it.
      child: Stack(
        children: [
          if (showThumbnail)
            Positioned.fill(
              child: thumbnail == null
                  ? ColoredBox(
                      key: ValueKey<String>(
                        'storyboard-cut-thumb-empty-${cut.id.value}',
                      ),
                      color: colorScheme.surfaceContainerHighest,
                    )
                  : Center(
                      child: RawImage(
                        key: ValueKey<String>(
                          'storyboard-cut-thumb-${cut.id.value}',
                        ),
                        image: thumbnail,
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topLeft,
              child: _scrim(
                context,
                Text(
                  cut.name,
                  key: ValueKey<String>('storyboard-cut-title-${cut.id.value}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.max(0, width - 8) * 0.6,
              ),
              child: storyboardLayer == null
                  ? _scrim(
                      context,
                      Text(
                        'No Storyboard Layer',
                        key: ValueKey<String>(
                          'storyboard-layer-empty-${cut.id.value}',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Container(
                      key: ValueKey<String>(
                        'storyboard-layer-strip-${cut.id.value}',
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        storyboardLayer.name,
                        key: ValueKey<String>(
                          'storyboard-layer-name-${cut.id.value}',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
            ),
          ),
          // The conte sheet's TIME column: cumulative time at the cut's end.
          if (width >= 48)
            Positioned(
              right: 0,
              bottom: 0,
              child: _scrim(
                context,
                Text(
                  totalLabel,
                  key: ValueKey<String>('storyboard-cut-total-${cut.id.value}'),
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
