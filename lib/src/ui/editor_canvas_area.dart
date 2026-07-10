import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/canvas_viewport.dart';
import '../models/layer_id.dart';
import 'brush/brush_tool_state.dart';
import 'brush/main_canvas_brush_host.dart';
import 'camera/camera_frame_overlay.dart';
import 'canvas/canvas_layer_stack_view.dart';
import 'canvas/layer_pose_paint.dart';
import 'canvas/layer_position_gizmo.dart';
import 'editor_session_manager.dart';
import 'playback/canvas_playback_view.dart';
import 'playback/canvas_scrub_preview.dart';
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
      // The session subscription lives HERE now (HomePage no longer
      // setStates the world). Committed seeks retarget the editing stack
      // through frameSeekCommitted — deliberately NOT the frame cursor,
      // whose per-move scrub firehose must never rebuild the brush host.
      listenable: Listenable.merge([
        session,
        session.frameSeekCommitted,
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
            // Ruler scrubs swap the content the same way playback does
            // (enter/leave only) — the per-move updates repaint just the
            // preview painter through the cursor listenable.
            return ValueListenableBuilder<bool>(
              valueListenable: session.frameScrubActive,
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
      },
    );
  }

  Widget _buildInteractiveCanvas(
    EditorSessionManager session, {
    required bool isCameraLayerActive,
    required bool showCameraOverlay,
  }) {
    final isPlaybackActive = session.playback.isActive;
    // A ruler scrub shows the composite-cache preview (playback display
    // machinery) — the editing chrome (layer stacks, overlays, gizmo)
    // holds off exactly like during playback.
    final isScrubbing = !isPlaybackActive && session.frameScrubActive.value;
    final layerStack = session.editingCanvasStack;
    final showAboveLayers =
        !isPlaybackActive && !isScrubbing && layerStack.above.isNotEmpty;
    final selection = isCameraLayerActive
        ? session.cameraBackdropSelection
        : session.activeBrushEditorSelection;
    // The layer shown in the interactive view draws POSED (always-applied
    // transforms, active layer included) with draw-through input.
    final interactivePose = selection == null
        ? null
        : session.layerCanvasPoseSample(selection.layerId);
    // The CUT-level pose (storyboard V-row fx, R9-B): with fx on, the
    // editing canvas shows the cut's transform exactly like the layer fx —
    // the paper stays put, all layer CONTENT rides the pose. The active
    // layer's wrap composes cut ∘ layer into ONE pose sample (similarities
    // compose exactly), so draw-through keeps landing strokes in artwork
    // coordinates through the single Transform's hit-test inverse.
    final canvasSize = session.activeCut.canvasSize;
    final cutPoseSample = session.activeCutCanvasPoseSample();
    final interactiveWrapPose = cutPoseSample == null
        ? interactivePose
        : interactivePose == null
        ? cutPoseSample
        : composeLayerPoseSamples(cutPoseSample, interactivePose, canvasSize);
    // The Position drag gizmo: only while the active layer's Transform
    // lanes are twirled open (deliberate transform-editing mode) and its
    // fx apply.
    final activeLayer = session.activeLayer;
    final showPositionGizmo =
        !isPlaybackActive &&
        !isScrubbing &&
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
          // editing. During playback the composite covers everything. Under
          // an active CUT pose (R9-B) the paper splits out of the wrap: the
          // canvas is the static stage, only the content rides the pose.
          viewportUnderlayBuilder: isPlaybackActive || isScrubbing
              ? null
              : (context, viewport) {
                  final below = CanvasLayerStackView(
                    layers: layerStack.below,
                    imageCache: session.layerFrameImageCache,
                    canvasSize: canvasSize,
                    viewport: viewport,
                    paintPaper: cutPoseSample == null,
                  );
                  if (cutPoseSample == null) {
                    return below;
                  }
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CanvasLayerStackView(
                          layers: const [],
                          imageCache: session.layerFrameImageCache,
                          canvasSize: canvasSize,
                          viewport: viewport,
                          paintPaper: true,
                        ),
                      ),
                      Positioned.fill(
                        child: Transform(
                          transform: layerPoseViewportWrapMatrix(
                            cutPoseSample.pose,
                            canvasSize,
                            viewport,
                            anchorPoint: cutPoseSample.anchorPoint,
                          ),
                          child: below,
                        ),
                      ),
                    ],
                  );
                },
          interactiveContentOpacity: layerStack.activeLayerOpacity,
          interactiveContentPose: interactiveWrapPose,
          // The playback view renders the camera framing itself; the editing
          // overlay would show a stale playhead pose on top of it. A scrub
          // keeps the CAMERA overlay only — the preview is the current view
          // moving through time, so the frame stays visible and rides the
          // cursor.
          viewportOverlayBuilder:
              (showCameraOverlay || showAboveLayers || showPositionGizmo) &&
                  !isPlaybackActive
              ? (context, viewport) => Stack(
                  children: [
                    if (showAboveLayers)
                      Positioned.fill(
                        child: Builder(
                          builder: (context) {
                            final above = CanvasLayerStackView(
                              layers: layerStack.above,
                              imageCache: session.layerFrameImageCache,
                              canvasSize: canvasSize,
                              viewport: viewport,
                            );
                            if (cutPoseSample == null) {
                              return above;
                            }
                            // Above-layers ride the cut pose too (R9-B);
                            // the camera overlay and the gizmo below stay
                            // unposed — they are canvas-space chrome.
                            return Transform(
                              transform: layerPoseViewportWrapMatrix(
                                cutPoseSample.pose,
                                canvasSize,
                                viewport,
                                anchorPoint: cutPoseSample.anchorPoint,
                              ),
                              child: above,
                            );
                          },
                        ),
                      ),
                    if (showCameraOverlay)
                      Positioned.fill(
                        // The cursor subscription keeps the frame gliding
                        // along its animated pose during scrubs (and after
                        // committed seeks) without any wider rebuild.
                        child: ListenableBuilder(
                          listenable: session.editingFrameCursor,
                          builder: (context, _) => CameraFrameOverlay(
                            pose: session.cameraPoseAtCurrentFrame,
                            cameraFrameSize: session.cameraFrameSize,
                            viewport: viewport,
                            // Dim belongs to camera-view mode; plain
                            // manipulation keeps the artwork undimmed.
                            dimOpacity: widget.cameraViewEnabled.value
                                ? widget.cameraDimOpacity.value
                                : 0,
                            interactive: isCameraLayerActive && !isScrubbing,
                            onPoseCommitted:
                                session.setCameraKeyframeAtCurrentFrame,
                          ),
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
                  cutFxEnabledOf: session.isCutFxEnabled,
                  cutPictureVisibleOf: session.isCutPictureVisible,
                  viewport: viewport,
                )
              : isScrubbing
              ? (context, viewport) => CanvasScrubPreview(
                  frameCursor: session.editingFrameCursor,
                  compositeCache: session.cutFrameCompositeCache,
                  cut: session.activeCut,
                  qualityOf: () => session.playbackQuality,
                  // The cut pose follows the editing canvas (R9-B): fx-gated
                  // per cursor frame, identity when off.
                  cutPoseSampleAt: (frame) =>
                      session.activeCutCanvasPoseSample(frameIndex: frame),
                  viewport: viewport,
                )
              : null,
        ),
      ),
    );
  }
}
