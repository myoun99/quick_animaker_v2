import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/canvas_viewport.dart';
import '../models/layer_id.dart';
import 'brush/brush_tool_state.dart';
import 'brush/main_canvas_brush_host.dart';
import 'camera/camera_frame_overlay.dart';
import 'canvas/canvas_layer_stack_view.dart';
import 'canvas/layer_position_gizmo.dart';
import 'editor_session_manager.dart';
import 'playback/canvas_playback_view.dart';
import 'timeline/layer_label_controls.dart';
import 'timeline/transform_lane_editing.dart';

/// The central drawing area: the interactive brush canvas with its layer
/// composites, camera overlay and playback swap.
///
/// Owns the [CanvasViewport] (pan/zoom) — the hottest piece of view state —
/// so panning rebuilds only this subtree. The brush tool and camera-view
/// state are owned by the workspace (they are shared with dockable panels)
/// and consumed here through listenables, again keeping their rebuilds
/// scoped to this subtree.
class EditorCanvasArea extends StatefulWidget {
  const EditorCanvasArea({
    super.key,
    required this.session,
    required this.brushToolState,
    required this.cameraViewEnabled,
    required this.cameraDimOpacity,
    this.expandedLaneLayerIds,
  });

  final EditorSessionManager session;

  /// The active brush tool + settings (workspace-owned; the tools and
  /// brush-settings panels write it).
  final ValueListenable<BrushToolState> brushToolState;

  /// Camera view mode: overlay shown with the outside dimmed.
  final ValueListenable<bool> cameraViewEnabled;
  final ValueListenable<double> cameraDimOpacity;

  /// The timeline's lane twirl-down state (workspace-owned): the Position
  /// drag gizmo shows only while the active layer's Transform lanes are
  /// open, so the handle never blocks ordinary drawing.
  final ValueListenable<Set<LayerId>>? expandedLaneLayerIds;

  @override
  State<EditorCanvasArea> createState() => _EditorCanvasAreaState();
}

class _EditorCanvasAreaState extends State<EditorCanvasArea> {
  CanvasViewport _canvasViewport = CanvasViewport();

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.brushToolState,
        widget.cameraViewEnabled,
        widget.cameraDimOpacity,
        ?widget.expandedLaneLayerIds,
      ]),
      builder: (context, _) {
        final isCameraLayerActive = session.isCameraLayerActive;
        final showCameraOverlay =
            widget.cameraViewEnabled.value || isCameraLayerActive;
        // Playback swaps only the viewport CONTENT (via the panel's
        // contentOverride), so the panel shell — zoom buttons, panbars —
        // keeps working while playing. Listen to enter/leave ONLY:
        // subscribing this subtree to every playback tick rebuilt the whole
        // panel at fps and caused real frame drops.
        return ValueListenableBuilder<bool>(
          valueListenable: session.playback.isActiveListenable,
          builder: (context, _, _) {
            return _buildInteractiveCanvas(
              session,
              isCameraLayerActive: isCameraLayerActive,
              showCameraOverlay: showCameraOverlay,
            );
          },
        );
      },
    );
  }

  Widget _buildInteractiveCanvas(
    EditorSessionManager session, {
    required bool isCameraLayerActive,
    required bool showCameraOverlay,
  }) {
    final isPlaybackActive = session.playback.isActive;
    final layerStack = session.editingCanvasStack;
    final showAboveLayers = !isPlaybackActive && layerStack.above.isNotEmpty;
    final selection = isCameraLayerActive
        ? session.cameraBackdropSelection
        : session.activeBrushEditorSelection;
    // The layer shown in the interactive view draws POSED (always-applied
    // transforms, active layer included) with draw-through input.
    final interactivePose = selection == null
        ? null
        : session.layerCanvasPoseSample(selection.layerId);
    // The Position drag gizmo: only while the active layer's Transform
    // lanes are twirled open (deliberate transform-editing mode) and its
    // fx apply.
    final activeLayer = session.activeLayer;
    final showPositionGizmo =
        !isPlaybackActive &&
        !isCameraLayerActive &&
        activeLayer != null &&
        layerKindShowsFxToggle(activeLayer.kind) &&
        session.isLayerFxEnabled(activeLayer.id) &&
        (widget.expandedLaneLayerIds?.value.contains(activeLayer.id) ?? false);
    // Camera mode retargets the Fit button at the camera frame's bounds —
    // fitting the cut canvas there framed the wrong rectangle.
    final fitFocusRect = isCameraLayerActive
        ? cameraFrameBoundsInCanvas(
            pose: session.cameraPoseAtCurrentFrame,
            cameraFrameSize: session.cameraFrameSize,
          )
        : null;
    return RepaintBoundary(
      child: KeyedSubtree(
        key: const ValueKey<String>('main-canvas-brush-host-container'),
        child: MainCanvasBrushHost(
          // Camera mode still needs artwork on screen: fall
          // back to the first drawn layer at the playhead.
          selection: selection,
          canvasSize: session.activeCut.canvasSize,
          frameStore: session.brushFrameStore,
          cacheInvalidationSink: session.cacheInvalidationHub,
          historyManager: session.historyManager,
          viewport: _canvasViewport,
          onViewportChanged: (viewport) {
            setState(() => _canvasViewport = viewport);
          },
          selectionLabels: session.canvasSelectionLabels,
          brushToolState: widget.brushToolState.value,
          fitFocusRect: fitFocusRect,
          // Layers below/above the active one composite around the
          // interactive view from the layer image cache — this is what makes
          // the other layers (and their visibility/opacity) visible while
          // editing. During playback the composite covers everything.
          viewportUnderlayBuilder: isPlaybackActive
              ? null
              : (context, viewport) => CanvasLayerStackView(
                  layers: layerStack.below,
                  imageCache: session.layerFrameImageCache,
                  canvasSize: session.activeCut.canvasSize,
                  viewport: viewport,
                  paintPaper: true,
                ),
          interactiveContentOpacity: layerStack.activeLayerOpacity,
          interactiveContentPose: interactivePose,
          // The playback view renders the camera framing itself; the editing
          // overlay would show a stale playhead pose on top of it.
          viewportOverlayBuilder:
              (showCameraOverlay || showAboveLayers || showPositionGizmo) &&
                  !isPlaybackActive
              ? (context, viewport) => Stack(
                  children: [
                    if (showAboveLayers)
                      Positioned.fill(
                        child: CanvasLayerStackView(
                          layers: layerStack.above,
                          imageCache: session.layerFrameImageCache,
                          canvasSize: session.activeCut.canvasSize,
                          viewport: viewport,
                        ),
                      ),
                    if (showCameraOverlay)
                      Positioned.fill(
                        child: CameraFrameOverlay(
                          pose: session.cameraPoseAtCurrentFrame,
                          cameraFrameSize: session.cameraFrameSize,
                          viewport: viewport,
                          // Dim belongs to camera-view mode; plain
                          // manipulation keeps the artwork undimmed.
                          dimOpacity: widget.cameraViewEnabled.value
                              ? widget.cameraDimOpacity.value
                              : 0,
                          interactive: isCameraLayerActive,
                          onPoseCommitted:
                              session.setCameraKeyframeAtCurrentFrame,
                        ),
                      ),
                    if (showPositionGizmo)
                      Positioned.fill(
                        child: LayerPositionGizmo(
                          pose: session.layerPoseAtFrame(
                            activeLayer,
                            session.currentFrameIndex,
                          ),
                          viewport: viewport,
                          // ONE key at the playhead per drag (AE rule, one
                          // undo).
                          onPositionCommitted: (position) =>
                              session.updateLayerTransformTrack(
                                activeLayer.id,
                                transformTrackWithPositionDragged(
                                  activeLayer.transformTrack,
                                  frameIndex: session.currentFrameIndex,
                                  position: position,
                                ),
                                description: 'Move ${activeLayer.name}',
                              ),
                        ),
                      ),
                  ],
                )
              : null,
          contentOverride: isPlaybackActive
              ? (context, viewport) => CanvasPlaybackView(
                  controller: session.playback,
                  compositeCache: session.cutFrameCompositeCache,
                  qualityOf: () => session.playbackQuality,
                  prerenderProgress: session.prerenderScheduler.progress,
                  cameraViewEnabled: widget.cameraViewEnabled.value,
                  cameraFrameSize: session.cameraFrameSize,
                  cameraPoseOf: session.cameraPoseForCut,
                  viewport: viewport,
                )
              : null,
        ),
      ),
    );
  }
}
