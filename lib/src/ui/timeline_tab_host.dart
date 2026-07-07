import 'package:flutter/material.dart';

import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/layer_kind.dart';
import 'dialogs/delete_layer_dialog.dart';
import 'dialogs/frame_name_conflict_dialog.dart';
import 'dialogs/rename_frame_dialog.dart';
import 'dialogs/rename_layer_dialog.dart';
import 'editor_session_manager.dart';
import 'playback/canvas_playback_controller.dart';
import 'playback/playback_prerender_scheduler.dart';
import 'playback/playback_transport_controls.dart';
import '../models/transform_track.dart';
import '../services/camera_pose_resolver.dart';
import 'timeline/property_lane_model.dart';
import 'timeline/timeline_action_toolbar.dart';
import 'timeline/timeline_exposure_comma_drag_policy.dart';
import 'timeline/timeline_orientation.dart';
import 'timeline/timeline_panel.dart';
import 'timeline/transform_lane_editing.dart';
import 'timeline/transform_lane_policy.dart';

/// The Timeline tab's content: the timeline panel with its transport, cell
/// action toolbar and the layer/frame dialogs it triggers. All wiring lives
/// HERE (not in HomePage) so parallel work on other panels stays in other
/// files.
class TimelineTabHost extends StatefulWidget {
  const TimelineTabHost({
    super.key,
    required this.session,
    required this.orientation,
    required this.onOrientationChanged,
    required this.pixelsPerFrame,
    required this.onPixelsPerFrameChanged,
    required this.showSeconds,
    required this.onShowSecondsChanged,
    this.expandedLaneLayerIds = const {},
    this.onToggleLayerLanes,
  });

  final EditorSessionManager session;
  final TimelineOrientation orientation;
  final ValueChanged<TimelineOrientation> onOrientationChanged;
  final double pixelsPerFrame;
  final ValueChanged<double> onPixelsPerFrameChanged;
  final bool showSeconds;
  final ValueChanged<bool> onShowSecondsChanged;

  /// AE-style property-lane twirl-down state (host-owned so it survives
  /// tab switches).
  final Set<LayerId> expandedLaneLayerIds;
  final ValueChanged<LayerId>? onToggleLayerLanes;

  @override
  State<TimelineTabHost> createState() => _TimelineTabHostState();
}

class _TimelineTabHostState extends State<TimelineTabHost> {
  EditorSessionManager get _session => widget.session;

  /// The camera layer's AE Transform lanes; other layer kinds get lanes
  /// with the layer-transform work (L3) and FX features later.
  List<PropertyLaneRow> _lanesForLayer(Layer layer) {
    if (layer.kind != LayerKind.camera) {
      return const [];
    }
    final cut = _session.activeCut;
    return transformPropertyLanes(
      cut.camera.track,
      poseAt: (frameIndex) => resolveCameraPoseAt(
        camera: cut.camera,
        canvasSize: cut.canvasSize,
        frameIndex: frameIndex,
      ),
    );
  }

  /// Commits an edited camera track as one undo step; non-camera layers
  /// join with the layer-transform work.
  void _commitLaneEdit(Layer layer, TransformTrack? next, String description) {
    if (layer.kind != LayerKind.camera || next == null) {
      return;
    }
    _session.updateActiveCutCameraTrack(next, description: description);
  }

  PropertyLaneEditCallbacks get _laneEdit => PropertyLaneEditCallbacks(
    onToggleKeyAt: (layer, lane, frameIndex) {
      final track = _session.activeCut.camera.track;
      _commitLaneEdit(
        layer,
        transformTrackWithLaneKeyToggled(
          track,
          laneId: lane.laneId,
          frameIndex: frameIndex,
          // The navigator toggles at the playhead: freeze the property's
          // CURRENT resolved value there (AE behavior).
          resolvedPose: _session.cameraPoseAtCurrentFrame,
        ),
        '${lane.label} keyframe at frame ${frameIndex + 1}',
      );
    },
    onMoveKey: (layer, lane, fromFrame, toFrame) {
      _commitLaneEdit(
        layer,
        transformTrackWithLaneKeyMoved(
          _session.activeCut.camera.track,
          laneId: lane.laneId,
          fromFrame: fromFrame,
          toFrame: toFrame,
        ),
        'Move ${lane.label} keyframe to frame ${toFrame + 1}',
      );
    },
    onRemoveKey: (layer, lane, frameIndex) {
      _commitLaneEdit(
        layer,
        transformTrackWithLaneKeyRemoved(
          _session.activeCut.camera.track,
          laneId: lane.laneId,
          frameIndex: frameIndex,
        ),
        'Delete ${lane.label} keyframe',
      );
    },
    onToggleHold: (layer, lane, frameIndex) {
      _commitLaneEdit(
        layer,
        transformTrackWithLaneHoldToggled(
          _session.activeCut.camera.track,
          laneId: lane.laneId,
          frameIndex: frameIndex,
        ),
        'Toggle hold on ${lane.label} keyframe',
      );
    },
    onSetValue: (layer, lane, frameIndex, input) {
      _commitLaneEdit(
        layer,
        transformTrackWithLaneValueEdited(
          _session.activeCut.camera.track,
          laneId: lane.laneId,
          frameIndex: frameIndex,
          input: input,
        ),
        'Set ${lane.label} at frame ${frameIndex + 1}',
      );
    },
  );

  Future<void> _deleteActiveLayer() async {
    final activeLayer = _session.activeLayer;
    if (activeLayer == null || !_session.canDeleteActiveLayer) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteLayerDialog(layerName: activeLayer.name),
    );
    if (!mounted || shouldDelete != true) {
      return;
    }

    _session.deleteActiveLayer();
  }

  Future<void> _renameActiveLayer() async {
    final activeLayer = _session.activeLayer;
    if (activeLayer == null) {
      return;
    }

    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => RenameLayerDialog(initialName: activeLayer.name),
    );
    if (!mounted || nextName == null) {
      return;
    }

    _session.renameActiveLayer(nextName);
  }

  Future<void> _renameSelectedFrame() async {
    if (_session.selectedFrame == null ||
        !_session.canRenameFrameAtCurrentFrame) {
      return;
    }

    final nextName = await showDialog<String>(
      context: context,
      builder: (context) =>
          RenameFrameDialog(initialName: _session.selectedFrameName ?? ''),
    );
    if (!mounted || nextName == null) {
      return;
    }

    final conflictingFrameId = _session.renameSelectedFrame(nextName);
    if (conflictingFrameId == null) {
      return;
    }

    final shouldLink = await showDialog<bool>(
      context: context,
      builder: (context) => const FrameNameConflictDialog(),
    );
    if (!mounted || shouldLink != true) {
      return;
    }

    _session.linkSelectedFrame(conflictingFrameId);
  }

  @override
  Widget build(BuildContext context) {
    // Playback ticks flow through the playback-only frame listenable —
    // never the session's notifyListeners — so during playback only this
    // panel rebuilds and the playhead follows every frame. The prerender
    // progress listenable keeps the cached-range green bar live while
    // frames warm in the background.
    return ValueListenableBuilder<PrerenderProgress>(
      valueListenable: _session.prerenderScheduler.progress,
      builder: (context, _, _) => ValueListenableBuilder<int?>(
        valueListenable: _session.playback.globalFrameIndexListenable,
        builder: (context, playbackGlobalFrame, _) => TimelinePanel(
          layers: _session.layers,
          activeLayerId: _session.activeLayerId,
          currentFrameIndex: playbackGlobalFrame == null
              ? _session.currentFrameIndex
              : _session.playback.position?.localFrameIndex ??
                    _session.currentFrameIndex,
          isFrameCached: _session.isPlaybackFrameCached,
          playbackFrameCount: _session.activeCutPlaybackFrameCount,
          exposureStateForLayer: _session.exposureStateForLayer,
          frameNameForLayer: _session.frameNameForLayer,
          onSelectLayer: _session.selectLayer,
          // Ruler scrubs during playback SEEK the playback clock instead of
          // moving the (hidden) editing playhead.
          onSelectFrame: (frameIndex) {
            if (_session.playback.isActive) {
              _session.playback.seekToLocalFrame(frameIndex);
            } else {
              _session.selectFrameIndex(frameIndex);
            }
          },
          onAddLayer: _session.addLayer,
          onToggleLayerVisibility: _session.toggleLayerVisibility,
          onLayerOpacityChanged: (layerId, opacity) {
            _session.setLayerOpacity(layerId: layerId, opacity: opacity);
          },
          onToggleLayerTimesheet: _session.toggleLayerTimesheet,
          onLayerMarkSelected: _session.setLayerMark,
          // Comma edge drags preview live from the session's drag-start
          // snapshot and commit as ONE undo entry on release.
          commaDrag: TimelineCommaDragCallbacks(
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
          orientation: widget.orientation,
          onOrientationChanged: widget.onOrientationChanged,
          pixelsPerFrame: widget.pixelsPerFrame,
          onPixelsPerFrameChanged: widget.onPixelsPerFrameChanged,
          showSeconds: widget.showSeconds,
          onShowSecondsChanged: widget.onShowSecondsChanged,
          projectFps: _session.projectFps,
          expandedLaneLayerIds: widget.expandedLaneLayerIds,
          onToggleLayerLanes: widget.onToggleLayerLanes,
          lanesForLayer: _lanesForLayer,
          laneEdit: _laneEdit,
          timelineActionToolbar: Row(
            children: [
              PlaybackTransportControls(
                controller: _session.playback,
                scope: PlaybackScope.activeCut,
                quality: _session.playbackQuality,
                onQualityChanged: _session.setPlaybackQuality,
                playbackStartFrame: () => _session.currentFrameIndex,
              ),
              Expanded(
                child: TimelineActionToolbar(
                  session: _session,
                  onRenameLayer: _renameActiveLayer,
                  onDeleteLayer: _deleteActiveLayer,
                  onRenameFrame: _renameSelectedFrame,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
