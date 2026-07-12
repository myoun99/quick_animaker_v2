import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/canvas_size.dart';
import '../models/canvas_viewport.dart';
import '../models/layer_id.dart';
import '../services/canvas_color_sampler.dart';
import '../services/canvas_flood_fill.dart';
import 'brush/brush_tool_state.dart';
import 'brush/canvas_selection_commands.dart';
import 'brush/canvas_view_commands.dart';
import 'canvas/viewport_canvas_transform.dart';
import 'brush/main_canvas_brush_host.dart';
import 'camera/camera_frame_overlay.dart';
import 'canvas/canvas_layer_stack_view.dart';
import 'canvas/layer_pose_paint.dart';
import 'canvas/layer_position_gizmo.dart';
import 'editor_session_manager.dart';
import 'playback/canvas_playback_view.dart';
import 'playback/canvas_scrub_preview.dart';
import 'storyboard_cut_fade_policy.dart' show cutFadeTargetColor;
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
    this.onBrushToolStateChanged,
    this.canvasViewCommands,
    this.canvasSelectionCommands,
    this.expandedLaneLayerIds,
    this.fillOptions,
  });

  final EditorSessionManager session;

  /// The active brush tool + settings (workspace-owned; the tools and
  /// brush-settings panels write it).
  final ValueListenable<BrushToolState> brushToolState;

  /// Write-back to the workspace-owned tool state: eyedropper picks land
  /// the sampled color (and return to the painting tool) through here.
  final ValueChanged<BrushToolState>? onBrushToolStateChanged;

  /// The app-level rotate/flip shortcut channel (P8), forwarded to the
  /// canvas panel which binds the actual viewport handlers.
  final CanvasViewCommands? canvasViewCommands;

  /// The app-level selection shortcut channel (P9: Ctrl+D, nudges),
  /// forwarded the same way.
  final CanvasSelectionCommands? canvasSelectionCommands;

  /// Camera view mode: overlay shown with the outside dimmed.
  final ValueListenable<bool> cameraViewEnabled;
  final ValueListenable<double> cameraDimOpacity;

  /// The timeline's lane twirl-down state (workspace-owned): the Position
  /// drag gizmo shows only while the active layer's Transform lanes are
  /// open, so the handle never blocks ordinary drawing.
  final ValueListenable<Set<LayerId>>? expandedLaneLayerIds;

  /// The fill tool's flood options (Tool Settings knobs, R11-④); null
  /// keeps the defaults.
  final ValueListenable<FloodFillOptions>? fillOptions;

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
        // Onion-skin toggles/pegs re-plan the underlay ghosts (P2).
        session.onionSkinSettings,
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

  /// Wraps editing-canvas content in the CUT pose (R9-B) — identity
  /// pass-through when [sample] is null. Content only: the paper, the
  /// camera overlay chrome and the fade wash stay outside.
  Widget _wrapInCutPose(
    Widget child, {
    required LayerPoseSample? sample,
    required CanvasSize canvasSize,
    required CanvasViewport viewport,
  }) {
    if (sample == null) {
      return child;
    }
    return Transform(
      transform: layerPoseViewportWrapMatrix(
        sample.pose,
        canvasSize,
        viewport,
        anchorPoint: sample.anchorPoint,
      ),
      child: child,
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
    // The cut FADE follows the fx switch too (R9-C: fx ALWAYS reflects —
    // dark faded frames are worked with fx off): a wash of the fade target
    // color over the canvas, above the content, below the chrome.
    final cutFadeOpacity = session.activeCutEditingFadeOpacity();
    final showFadeWash =
        !isPlaybackActive && !isScrubbing && cutFadeOpacity < 1;
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
          viewCommands: widget.canvasViewCommands,
          selectionCommands: widget.canvasSelectionCommands,
          // P5 eyedropper: sample the VISIBLE composite ("pick what you
          // see"). Picks NEVER switch tools (R11-②): the eyedropper stays
          // armed until the user changes tools, Alt-picks keep the
          // painting tool.
          sampleColorAt: (point) => sampleCompositeColor(
            cut: session.activeCut,
            frameIndex: session.currentFrameIndex,
            surfaceResolver: session.brushSurfaceForLayerFrame,
            point: point,
            fxBypassedLayerIds: session.fxBypassedLayerIds,
            paperColor: session.projectBackground.argb,
          ),
          onEyedropperPick: (color) => widget.onBrushToolStateChanged?.call(
            widget.brushToolState.value.copyWith(color: color),
          ),
          onAltColorPick: (color) => widget.onBrushToolStateChanged?.call(
            widget.brushToolState.value.copyWith(color: color),
          ),
          // P6 fill: the flood region as ONE mask dab; the panel commits it
          // through the stroke funnel onto the active layer's frame.
          fillDabAt: (point, color) => buildFillDab(
            cut: session.activeCut,
            frameIndex: session.currentFrameIndex,
            surfaceResolver: session.brushSurfaceForLayerFrame,
            point: point,
            color: color,
            fxBypassedLayerIds: session.fxBypassedLayerIds,
            options: widget.fillOptions?.value ?? const FloodFillOptions(),
            paperColor: session.projectBackground.argb,
          ),
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
                    layers: [
                      ...layerStack.below,
                      // Onion ghosts (P2) sit ABOVE the other layers and
                      // directly UNDER the active drawing; playback and
                      // scrubs never reach here, so they auto-hide.
                      ...session.onionSkinCanvasRequests(),
                    ],
                    imageCache: session.layerFrameImageCache,
                    canvasSize: canvasSize,
                    viewport: viewport,
                    paintPaper: cutPoseSample == null,
                    paperBackground: session.projectBackground,
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
                          paperBackground: session.projectBackground,
                        ),
                      ),
                      Positioned.fill(
                        child: _wrapInCutPose(
                          below,
                          sample: cutPoseSample,
                          canvasSize: canvasSize,
                          viewport: viewport,
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
              (showCameraOverlay ||
                      showAboveLayers ||
                      showPositionGizmo ||
                      showFadeWash) &&
                  !isPlaybackActive
              ? (context, viewport) => Stack(
                  children: [
                    if (showAboveLayers)
                      Positioned.fill(
                        // Above-layers ride the cut pose too (R9-B); the
                        // camera overlay stays unposed (canvas chrome).
                        child: _wrapInCutPose(
                          CanvasLayerStackView(
                            layers: layerStack.above,
                            imageCache: session.layerFrameImageCache,
                            canvasSize: canvasSize,
                            viewport: viewport,
                          ),
                          sample: cutPoseSample,
                          canvasSize: canvasSize,
                          viewport: viewport,
                        ),
                      ),
                    if (showFadeWash)
                      Positioned.fill(
                        // The cut fade as a wash of the fade target color
                        // over the canvas (R9-C) — above every layer,
                        // below the chrome; matches playback's overlay at
                        // (1 − fade).
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _CutFadeWashPainter(
                              viewport: viewport,
                              canvasSize: canvasSize,
                              color: cutFadeTargetColor(session.activeCut)
                                  .withValues(
                                    alpha: (1 - cutFadeOpacity).clamp(0.0, 1.0),
                                  ),
                            ),
                          ),
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
                        // The gizmo rides the cut pose too (R9-C): the
                        // crosshair sits ON the posed picture and the
                        // wrap's hit-test inverse maps drag deltas back
                        // into the layer's own canvas space — the
                        // committed Position stays unposed.
                        child: _wrapInCutPose(
                          LayerPositionGizmo(
                            pose: session.layerPoseAtFrame(
                              activeLayer,
                              session.currentFrameIndex,
                            ),
                            viewport: viewport,
                            // ONE key at the playhead per drag (AE rule,
                            // one undo).
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
                          sample: cutPoseSample,
                          canvasSize: canvasSize,
                          viewport: viewport,
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
                  background: session.projectBackground,
                )
              : isScrubbing
              ? (context, viewport) => CanvasScrubPreview(
                  frameCursor: session.editingFrameCursor,
                  compositeCache: session.cutFrameCompositeCache,
                  cut: session.activeCut,
                  qualityOf: () => session.playbackQuality,
                  // The cut pose AND fade follow the editing canvas
                  // (R9-B/C): fx-gated per cursor frame, identity when off.
                  cutPoseSampleAt: (frame) =>
                      session.activeCutCanvasPoseSample(frameIndex: frame),
                  cutFadeOpacityAt: (frame) =>
                      session.activeCutEditingFadeOpacity(frameIndex: frame),
                  fadeColor: cutFadeTargetColor(session.activeCut),
                  viewport: viewport,
                  paperBackground: session.projectBackground,
                )
              : null,
        ),
      ),
    );
  }
}

/// The editing canvas's cut-fade wash (R9-C): the fade target color over
/// the canvas rect at (1 − fadeOpacity), under the panel viewport — the
/// same overlay playback paints, so an fx-on faded frame reads identically
/// while editing.
class _CutFadeWashPainter extends CustomPainter {
  const _CutFadeWashPainter({
    required this.viewport,
    required this.canvasSize,
    required this.color,
  });

  final CanvasViewport viewport;
  final CanvasSize canvasSize;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    applyViewportTransform(canvas, viewport);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        canvasSize.width.toDouble(),
        canvasSize.height.toDouble(),
      ),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CutFadeWashPainter oldDelegate) =>
      oldDelegate.viewport != viewport ||
      oldDelegate.canvasSize != canvasSize ||
      oldDelegate.color != color;
}
