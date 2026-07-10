import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/cut.dart';
import 'cut/cut_note_dialog.dart';
import 'dialogs/canvas_size_dialog.dart';
import 'dialogs/rename_cut_dialog.dart';
import 'editor_session_manager.dart';
import 'playback/canvas_playback_controller.dart';
import 'playback/playback_prerender_scheduler.dart';
import 'playback/playback_transport_controls.dart';
import 'storyboard_panel.dart';
import 'timeline/timeline_exposure_comma_drag_policy.dart'
    show TimelineCommaDragCallbacks;
import 'storyboard_playhead_mapping.dart';
import 'timeline/timeline_frame_range_policy.dart' show timelineSecondsLabel;
import 'timeline/timeline_panel.dart' show TimelinePanel;

/// The Storyboard tab's content: its own toolbar row (frame counter,
/// seconds toggle, zoom slider — the same keys as the timeline tab's, only
/// one is ever on screen), the all-cuts transport, the storyboard panel and
/// the cut dialogs it triggers. All wiring lives HERE (not in HomePage).
class StoryboardTabHost extends StatefulWidget {
  const StoryboardTabHost({
    super.key,
    required this.session,
    required this.pixelsPerFrame,
    required this.onPixelsPerFrameChanged,
    required this.showSeconds,
    required this.onShowSecondsChanged,
    required this.thumbnailFor,
  });

  final EditorSessionManager session;
  final double pixelsPerFrame;
  final ValueChanged<double> onPixelsPerFrameChanged;
  final bool showSeconds;
  final ValueChanged<bool> onShowSecondsChanged;

  /// Build-time thumbnail resolver, owned above the tabs so the cache
  /// survives tab switches.
  final ui.Image? Function(Cut cut)? thumbnailFor;

  @override
  State<StoryboardTabHost> createState() => _StoryboardTabHostState();
}

class _StoryboardTabHostState extends State<StoryboardTabHost> {
  EditorSessionManager get _session => widget.session;

  /// Rail view state (waveform eyes, twirled-down lanes). Session-scoped
  /// like the timeline's lane expansion; lost on tab switch for now (the
  /// host rebuilds) — hoist to the workspace if that stings.
  final Set<String> _hiddenWaveformSeRows = {};
  final Set<String> _expandedSeAudioRows = {};
  final Set<String> _expandedOpacityTracks = {};

  void _toggleSetEntry(Set<String> set, String key) {
    setState(() {
      if (!set.add(key)) {
        set.remove(key);
      }
    });
  }

  Future<void> _editActiveCutNote() async {
    final initialNote = _session.activeCutNote;
    if (initialNote == null) {
      return;
    }

    final nextNote = await showDialog<String>(
      context: context,
      builder: (context) => CutNoteDialog(initialNote: initialNote),
    );
    if (!mounted || nextNote == null) {
      return;
    }

    _session.updateActiveCutNote(nextNote);
  }

  Future<void> _renameActiveCut() async {
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) =>
          RenameCutDialog(initialName: _session.activeCut.name),
    );
    if (!mounted || nextName == null || nextName.trim().isEmpty) {
      return;
    }

    _session.renameActiveCut(nextName);
  }

  Future<void> _resizeActiveCutCanvas() async {
    final request = await showDialog<CanvasResizeRequest>(
      context: context,
      builder: (context) =>
          CanvasSizeDialog(initialSize: _session.activeCut.canvasSize),
    );
    if (!mounted || request == null) {
      return;
    }

    _session.resizeActiveCutCanvas(request.size, anchor: request.anchor);
  }

  Widget _toolbarRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
      child: Row(
        children: [
          Text(
            widget.showSeconds
                ? timelineSecondsLabel(
                    _session.currentFrameIndex + 1,
                    _session.projectFps,
                  )
                : '${_session.currentFrameIndex + 1}',
            key: const ValueKey<String>('timeline-current-frame-counter'),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
          const Spacer(),
          IconButton(
            key: const ValueKey<String>('timeline-time-display-toggle-button'),
            tooltip: widget.showSeconds ? 'Show Frames' : 'Show Seconds',
            onPressed: () => widget.onShowSecondsChanged(!widget.showSeconds),
            icon: Icon(
              widget.showSeconds ? Icons.timer : Icons.timer_outlined,
              size: 18,
            ),
          ),
          Icon(Icons.zoom_out, size: 16, color: colorScheme.onSurfaceVariant),
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
          Icon(Icons.zoom_in, size: 16, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Same rebuild channels as the timeline tab: playback ticks through the
    // playback-only listenable, green-bar updates through the prerender
    // progress.
    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: ValueListenableBuilder<PrerenderProgress>(
        valueListenable: _session.prerenderScheduler.progress,
        builder: (context, _, _) => ValueListenableBuilder<int?>(
          valueListenable: _session.playback.globalFrameIndexListenable,
          builder: (context, _, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _toolbarRow(context),
              PlaybackTransportControls(
                controller: _session.playback,
                scope: PlaybackScope.allCuts,
                quality: _session.playbackQuality,
                onQualityChanged: _session.setPlaybackQuality,
                // Play from the storyboard playhead, like the timeline's
                // transport does.
                playbackStartFrame: () =>
                    storyboardPlayheadFrame(_session) ?? 0,
              ),
              Expanded(
                child: StoryboardPanel(
                  project: _session.repository.requireProject(),
                  // While playing, the highlight follows the PLAYING cut
                  // (onStopped syncs the real active cut).
                  activeCutId: _session.playback.isActive
                      ? _session.playback.position?.cutId ??
                            _session.activeCutId
                      : _session.activeCutId,
                  onCutSelected: _session.selectCut,
                  onCutReordered: _session.reorderCut,
                  pixelsPerFrame: widget.pixelsPerFrame,
                  showSeconds: widget.showSeconds,
                  projectFps: _session.projectFps,
                  // Edge-grip trims preview live and commit ONE undo on
                  // release, like the timeline's comma drags.
                  cutTrim: StoryboardCutTrimCallbacks(
                    onBegin: (cutId, edge) =>
                        _session.beginCutEdgeDrag(cutId: cutId, edge: edge),
                    onUpdate: _session.updateCutEdgeDrag,
                    onEnd: _session.endCutEdgeDrag,
                    onCancel: _session.cancelCutEdgeDrag,
                  ),
                  playheadGlobalFrame: storyboardPlayheadFrame(_session),
                  onSeekGlobalFrame: (frame) =>
                      seekStoryboardGlobalFrame(_session, frame),
                  isFrameCached: (frame) =>
                      storyboardFrameCached(_session, frame),
                  thumbnailFor: widget.thumbnailFor,
                  audioPeaksFor: _session.audioPeaksStore.peaksFor,
                  // Rail parity with the timeline rows: waveform eyes,
                  // twirl-down audio lanes and the V track's cut-fade
                  // (Opacity) lane.
                  hiddenWaveformSeRows: _hiddenWaveformSeRows,
                  onToggleSeRowWaveform: (track, slot) => _toggleSetEntry(
                    _hiddenWaveformSeRows,
                    StoryboardPanel.seRowKey(track, slot),
                  ),
                  expandedSeAudioRows: _expandedSeAudioRows,
                  onToggleSeRowLane: (track, slot) => _toggleSetEntry(
                    _expandedSeAudioRows,
                    StoryboardPanel.seRowKey(track, slot),
                  ),
                  expandedOpacityTracks: _expandedOpacityTracks,
                  onToggleTrackLane: (track) =>
                      _toggleSetEntry(_expandedOpacityTracks, track.id.value),
                  onSetCutFade: (cutId, fadeIn, fadeOut) => _session.setCutFade(
                    cutId,
                    fadeInFrames: fadeIn,
                    fadeOutFrames: fadeOut,
                  ),
                  // FO=black / WO=white — the fade span's context menu.
                  onSetCutFadeTarget: _session.setCutFadeTarget,
                  // Timeline-parity layer controls on the ACTIVE cut's SE
                  // rows — the SAME session hooks the timeline host wires.
                  onToggleLayerVisibility: _session.toggleLayerVisibility,
                  onToggleLayerMuted: _session.toggleLayerMuted,
                  onLayerOpacityChanged: (layerId, opacity) => _session
                      .setLayerOpacity(layerId: layerId, opacity: opacity),
                  onLayerMarkSelected: _session.setLayerMark,
                  layerFxEnabledOf: _session.isLayerFxEnabled,
                  onToggleLayerFx: _session.toggleLayerFx,
                  // SE block tap-select: cut + layer + frame, like tapping
                  // the timeline's cells.
                  onSelectSeBlock: (cutId, layerId, blockStartFrame) {
                    _session.selectCut(cutId);
                    _session.selectLayer(layerId);
                    _session.selectFrameIndex(blockStartFrame);
                  },
                  // The ACTIVE cut's SE blocks reuse the timeline's comma
                  // edge grips (live preview + ONE undo per drag).
                  seCommaDrag: TimelineCommaDragCallbacks(
                    onBegin: (layerId, blockStartIndex, edge) =>
                        _session.beginExposureEdgeDrag(
                          layerId: layerId,
                          blockStartIndex: blockStartIndex,
                          edge: edge,
                        ),
                    onUpdate: _session.updateExposureEdgeDrag,
                    onEnd: _session.endExposureEdgeDrag,
                    onCancel: _session.cancelExposureEdgeDrag,
                  ),
                  // The Audio lane's slide edit (active cut).
                  onSetAudioClipOffset: _session.setAudioClipOffset,
                  onNewCut: _session.createCut,
                  onRenameActiveCut: _renameActiveCut,
                  onEditActiveCutNote: _editActiveCutNote,
                  onResizeActiveCutCanvas: _resizeActiveCutCanvas,
                  onDuplicateActiveCut: _session.duplicateActiveCut,
                  onMoveActiveCutLeft: _session.canMoveActiveCutLeft
                      ? _session.moveActiveCutLeft
                      : null,
                  onMoveActiveCutRight: _session.canMoveActiveCutRight
                      ? _session.moveActiveCutRight
                      : null,
                  onDeleteActiveCut: _session.deleteActiveCut,
                  onToggleActiveCutThumbnail:
                      _session.toggleActiveCutThumbnailFrame,
                  isThumbnailPinnedHere:
                      _session.isActiveCutThumbnailPinnedHere,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
