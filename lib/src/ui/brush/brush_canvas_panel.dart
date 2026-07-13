import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyEvent;

import '../../services/brush_stroke_commit_data.dart';
import '../../models/brush_dab.dart';
import '../../models/brush_frame_key.dart';
import '../../models/brush_paint_command_id.dart';
import '../../services/canvas_selection.dart';
import '../../models/canvas_point.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';
import '../../models/viewport_point.dart';
import '../../services/brush_frame_editing_coordinator.dart';
import '../../services/commands/brush_lift_move_history_command.dart';
import '../../services/commands/brush_selection_transform_history_command.dart';
import '../../services/commands/brush_stroke_history_command.dart';
import '../../services/cache_invalidation_executor.dart';
import '../../services/history_manager.dart';
import '../canvas/canvas_selection_layer.dart';
import '../canvas/canvas_viewport_gesture_layer.dart';
import '../canvas/interactive_brush_edit_canvas_view.dart';
import '../canvas/layer_pose_paint.dart';
import 'brush_canvas_defaults.dart';
import 'brush_tool_state.dart';
import '../dev_profile.dart';
import 'canvas_selection_commands.dart';
import 'selection_shape_history_command.dart';
import 'canvas_view_commands.dart';
import 'canvas_viewport_pan_metrics.dart';

/// A playback-follow reframe request for [BrushCanvasPanel.autoFrame]:
/// whenever [token] changes between widget updates the panel reframes the
/// viewport around [rect] (canvas space) — Fit-style when [panOnly] is
/// false (the timesheet's page turn), or a minimal zoom-preserving pan
/// that just brings [rect] into view when true (continuous-view scroll
/// following the playhead row).
class CanvasAutoFrameRequest {
  const CanvasAutoFrameRequest({
    required this.token,
    required this.rect,
    this.panOnly = false,
  });

  final Object token;
  final Rect rect;
  final bool panOnly;
}

/// Reusable Brush canvas panel for the production main-canvas brush route.
///
/// This widget is route-agnostic and behaves as an embedded canvas panel for
/// the main editor canvas area. Temporary debug controls are intentionally not
/// part of this panel.
class BrushCanvasPanel extends StatefulWidget {
  const BrushCanvasPanel({
    super.key,
    required this.coordinator,
    required this.availableFrameKeys,
    required this.cacheInvalidationSink,
    this.canvasSize = BrushCanvasDefaults.canvasSize,
    this.brushToolState = BrushToolState.defaults,
    this.historyManager,
    this.viewport,
    this.onViewportChanged,
    this.selectionLabels = const CanvasEditorSelectionLabels(),
    this.viewportOverlayBuilder,
    this.viewportUnderlayBuilder,
    this.interactiveContentOpacity = 1.0,
    this.interactiveContentPose,
    this.contentOverride,
    this.fitFocusRect,
    this.autoFrame,
    this.contentStrokeActive,
    this.sampleColorAt,
    this.onEyedropperPick,
    this.onAltColorPick,
    this.fillDabAt,
    this.viewCommands,
    this.selectionCommands,
    this.onStrokeInputActiveChanged,
    this.onSelectionInteractionChanged,
    this.allowViewRotation = true,
  }) : assert(
         coordinator != null || contentOverride != null,
         'Without a coordinator the panel needs a content override.',
       );

  /// Null only when [contentOverride] supplies the viewport content (e.g.
  /// the blank-canvas placeholder without an editable frame).
  final BrushFrameEditingCoordinator? coordinator;

  final List<BrushFrameKey> availableFrameKeys;
  final CacheInvalidationSink cacheInvalidationSink;
  final CanvasSize canvasSize;
  final BrushToolState brushToolState;
  final HistoryManager? historyManager;
  final CanvasViewport? viewport;
  final ValueChanged<CanvasViewport>? onViewportChanged;
  final CanvasEditorSelectionLabels selectionLabels;

  /// Optional layer stacked over the canvas inside the editor viewport,
  /// receiving the live viewport so it can transform canvas coordinates
  /// (e.g. the camera frame overlay, layers above the active one).
  final Widget Function(BuildContext context, CanvasViewport viewport)?
  viewportOverlayBuilder;

  /// Optional layer painted UNDER the interactive canvas (layers below the
  /// active one + the paper). When present, the interactive view skips its
  /// own opaque background so the underlay shows through.
  final Widget Function(BuildContext context, CanvasViewport viewport)?
  viewportUnderlayBuilder;

  /// Display opacity of the interactive layer itself (the active layer's
  /// visibility/opacity preview); strokes still commit at full strength.
  final double interactiveContentOpacity;

  /// The active layer's geometric transform at the playhead (null =
  /// identity). The interactive view wraps in the pose's screen matrix so
  /// the layer shows POSED exactly like every composite route, while hit
  /// testing inverse-maps pointers — strokes record in original artwork
  /// coordinates (draw-through). Brush sizes are artwork-space: the live
  /// stroke and the committed composite stay pixel-identical.
  final LayerPoseSample? interactiveContentPose;

  /// Replaces the interactive canvas INSIDE the panel shell (title, zoom
  /// toolbar and panbars keep working) — playback and the blank-canvas
  /// placeholder render through this. Receives the live viewport.
  final Widget Function(BuildContext context, CanvasViewport viewport)?
  contentOverride;

  /// Canvas-space rectangle the Fit button frames instead of the whole
  /// canvas (e.g. the camera frame's bounds while the camera layer is
  /// active). Null keeps Fit on the canvas itself.
  final Rect? fitFocusRect;

  /// Playback-follow reframing: when the request's token changes between
  /// updates the panel reframes onto its rect (see
  /// [CanvasAutoFrameRequest]). Null never reframes — the user owns the
  /// viewport.
  final CanvasAutoFrameRequest? autoFrame;

  /// Raised by contentOverride content that hosts its OWN brush input (the
  /// timesheet ink layer): while true, the panel's gesture layer holds
  /// navigation exactly as it does for the panel's own strokes.
  final ValueListenable<bool>? contentStrokeActive;

  /// Samples the VISIBLE composite color at a canvas point (P5); null
  /// disables the eyedropper tool and Alt-picks.
  final int? Function(CanvasPoint point)? sampleColorAt;

  /// A committed eyedropper pick (switches back to the painting tool).
  final ValueChanged<int>? onEyedropperPick;

  /// An Alt+click TEMPORARY pick while painting: color only, the active
  /// tool stays (the CSP muscle-memory shortcut).
  final ValueChanged<int>? onAltColorPick;

  /// Builds the fill-region dab for a tap (P6); the panel commits it
  /// through the exact stroke funnel. Null disables the fill tool.
  final BrushDab? Function(CanvasPoint point, int color)? fillDabAt;

  /// The app-level rotate/flip shortcut channel (P8); the panel binds its
  /// viewport-center handlers while mounted.
  final CanvasViewCommands? viewCommands;

  /// The app-level selection channel (P9: Ctrl+D, arrow nudges), bound by
  /// the selection layer while a selection tool is active.
  final CanvasSelectionCommands? selectionCommands;

  /// Stroke lifecycle for the host (R13-3): true at pen-down, false at
  /// stroke end/cancel — the session holds prerender warming while a
  /// stroke is live.
  final ValueChanged<bool>? onStrokeInputActiveChanged;

  /// Selection-drag lifecycle for the host (R15-⑤): the session blocks
  /// frame seeks/cut switches while a selection interaction is live.
  final ValueChanged<bool>? onSelectionInteractionChanged;

  /// False hides the rotate/flip toolbar controls and disables the
  /// rotation gestures — for hosts whose content layers speak zoom/pan
  /// only (the timesheet's ink and header-edit overlays).
  final bool allowViewRotation;

  @override
  State<BrushCanvasPanel> createState() => _BrushCanvasPanelState();
}

class _BrushCanvasPanelState extends State<BrushCanvasPanel> {
  late CanvasViewport _viewport = widget.viewport ?? CanvasViewport();
  CanvasViewport? _lastWidgetViewport;
  Size? _editorViewportSize;

  /// True while a brush stroke is in progress; the viewport gesture layer
  /// ignores wheel zooms and new pans so they cannot disturb the stroke.
  bool _strokeActive = false;

  /// True while a selection marquee/move drag is in progress (P9) — holds
  /// viewport gestures exactly like a stroke.
  bool _selectionDragActive = false;

  CanvasAutoFrameRequest? _pendingAutoFrame;

  /// True while Alt is held — the temporary eyedropper (R11-②): the cursor
  /// and hover swatch arm without switching tools.
  bool _altHeld = false;

  /// The pointer's viewport position + the composite color under it while
  /// the eyedropper cursor is armed; drives the hover swatch only.
  final ValueNotifier<({Offset position, int color})?> _eyedropperHover =
      ValueNotifier<({Offset position, int color})?>(null);

  @override
  void initState() {
    super.initState();
    _bindViewCommands();
    _altHeld = HardwareKeyboard.instance.isAltPressed;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    // A mid-stroke teardown must release the session's warm hold — a
    // leaked hold would gate prerendering forever. Same for a mid-drag
    // selection interaction (R15-⑤: a leaked hold would block seeks).
    if (_strokeActive) {
      widget.onStrokeInputActiveChanged?.call(false);
    }
    if (_selectionDragActive) {
      widget.onSelectionInteractionChanged?.call(false);
    }
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _eyedropperHover.dispose();
    widget.viewCommands?.unbind();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    final alt = HardwareKeyboard.instance.isAltPressed;
    if (alt != _altHeld && mounted) {
      setState(() => _altHeld = alt);
      if (!alt) {
        _eyedropperHover.value = null;
      }
    }
    return false;
  }

  /// Whether the eyedropper cursor + hover swatch are armed: the tool
  /// itself, or Alt held over a painting tool (the temporary pick).
  bool get _eyedropperCursorActive {
    if (widget.sampleColorAt == null) {
      return false;
    }
    final tool = widget.brushToolState.tool;
    if (tool == CanvasTool.eyedropper) {
      return widget.onEyedropperPick != null;
    }
    return _altHeld && canvasToolPaints(tool) && widget.onAltColorPick != null;
  }

  void _updateEyedropperHover(Offset localPosition) {
    final sample = widget.sampleColorAt;
    if (sample == null) {
      return;
    }
    final color = sample(
      _viewport.viewportToCanvas(
        ViewportPoint(x: localPosition.dx, y: localPosition.dy),
      ),
    );
    _eyedropperHover.value = color == null
        ? null
        : (position: localPosition, color: color);
  }

  void _bindViewCommands() {
    widget.viewCommands?.bind(
      rotateBy: _rotateAroundCenter,
      toggleFlipHorizontal: _toggleFlipHorizontal,
    );
  }

  @override
  void didUpdateWidget(covariant BrushCanvasPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.viewCommands, widget.viewCommands)) {
      oldWidget.viewCommands?.unbind();
      _bindViewCommands();
    }
    final request = widget.autoFrame;
    if (request == null || request.token == oldWidget.autoFrame?.token) {
      return;
    }
    // didUpdateWidget runs during the build phase — reframing notifies the
    // viewport's parent owner, so it must wait for the frame to end.
    final alreadyScheduled = _pendingAutoFrame != null;
    _pendingAutoFrame = request;
    if (alreadyScheduled) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = _pendingAutoFrame;
      _pendingAutoFrame = null;
      if (mounted && pending != null) {
        _autoFrame(pending);
      }
    });
  }

  void _autoFrame(CanvasAutoFrameRequest request) {
    final viewportSize = _resolvedEditorViewportSize();
    final next = request.panOnly
        ? _viewportRevealing(request.rect, viewportSize)
        : CanvasViewport.fitToCanvasRect(
            left: request.rect.left,
            top: request.rect.top,
            width: request.rect.width,
            height: request.rect.height,
            viewportWidth: viewportSize.width,
            viewportHeight: viewportSize.height,
          );
    if (next == _viewport) {
      return;
    }
    _setViewport(next);
  }

  /// The minimal zoom-preserving pan that brings [rect] (canvas space)
  /// into the viewport with a small margin; when the rect cannot fully
  /// fit, its top-left edge wins. Under rotation/flip the rect's mapped
  /// AABB is what must land inside.
  CanvasViewport _viewportRevealing(Rect rect, Size viewportSize) {
    const margin = 24.0;
    var panX = _viewport.panX;
    var panY = _viewport.panY;
    final unpanned = _viewport.copyWith(panX: 0, panY: 0);
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ]) {
      final mapped = unpanned.canvasToViewport(
        CanvasPoint(x: corner.dx, y: corner.dy),
      );
      minX = math.min(minX, mapped.x);
      maxX = math.max(maxX, mapped.x);
      minY = math.min(minY, mapped.y);
      maxY = math.max(maxY, mapped.y);
    }
    if (maxY + panY > viewportSize.height - margin) {
      panY = viewportSize.height - margin - maxY;
    }
    if (minY + panY < margin) {
      panY = margin - minY;
    }
    if (maxX + panX > viewportSize.width - margin) {
      panX = viewportSize.width - margin - maxX;
    }
    if (minX + panX < margin) {
      panX = margin - minX;
    }
    return _viewport.copyWith(panX: panX, panY: panY);
  }

  /// R13-3 shell memo: the panbars/zoom-rotate bar are a Material button
  /// forest that used to reconstruct on EVERY panel rebuild (each committed
  /// seek, tool switch, drag-preview notify). Their inputs are only the
  /// viewport geometry — memo by token, reuse the identical instances so
  /// the element tree prunes the whole subtree.
  ({CanvasViewport viewport, Size viewportSize, CanvasSize canvasSize,
      bool rotation, String title})? _shellBarsToken;
  Widget? _memoRightStripBar;
  Widget? _memoBottomBar;

  void _ensureShellBars() {
    final token = (
      viewport: _viewport,
      viewportSize: _resolvedEditorViewportSize(),
      canvasSize: widget.canvasSize,
      rotation: widget.allowViewRotation,
      title: widget.selectionLabels.title,
    );
    if (token == _shellBarsToken &&
        _memoRightStripBar != null &&
        _memoBottomBar != null) {
      return;
    }
    _shellBarsToken = token;
    _memoRightStripBar = CanvasViewportVerticalScrollbar(
      viewport: _viewport,
      editorViewportSize: _resolvedEditorViewportSize(),
      canvasSize: widget.canvasSize,
      onViewportChanged: _setViewportDuringPanbarDrag,
      onViewportChangeEnd: _syncViewportParent,
    );
    _memoBottomBar = _CanvasViewportBottomBar(
      viewport: _viewport,
      editorViewportSize: _resolvedEditorViewportSize(),
      canvasSize: widget.canvasSize,
      onViewportChanged: _setViewportDuringPanbarDrag,
      onViewportChangeEnd: _syncViewportParent,
      onZoomIn: _zoomInFromBar,
      onZoomOut: _zoomOutFromBar,
      onFit: _fitToView,
      onReset: _resetView,
      onRotateCcw: widget.allowViewRotation ? _rotateCcwFromBar : null,
      onRotateCw: widget.allowViewRotation ? _rotateCwFromBar : null,
      onFlipHorizontal: widget.allowViewRotation ? _toggleFlipHorizontal : null,
    );
  }

  Widget _memoizedRightStripBar() {
    _ensureShellBars();
    return _memoRightStripBar!;
  }

  Widget _memoizedBottomBar() {
    _ensureShellBars();
    return _memoBottomBar!;
  }

  // Named handlers (not closures) so the memoized bars capture stable
  // callbacks — a fresh closure per build would defeat nothing here, but
  // stale-capture bugs are impossible with tear-offs.
  void _zoomInFromBar() => _zoomAroundCenter(1.25);
  void _zoomOutFromBar() => _zoomAroundCenter(0.8);
  void _rotateCcwFromBar() => _rotateAroundCenter(-15);
  void _rotateCwFromBar() => _rotateAroundCenter(15);

  @override
  Widget build(BuildContext context) {
    if (widget.viewport != null && widget.viewport != _lastWidgetViewport) {
      _viewport = widget.viewport!;
      _lastWidgetViewport = widget.viewport;
    }

    return Padding(
      key: const ValueKey<String>('brush-canvas-panel'),
      // Zero: panels sit flush against the dock and the timeline (the
      // shell draws its own chrome).
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fallbackSize = Size(
            widget.canvasSize.width.toDouble(),
            widget.canvasSize.height.toDouble(),
          );
          final boundedWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : fallbackSize.width;
          final boundedHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : fallbackSize.height +
                    _CanvasEditorPanelShell.statusStripHeight +
                    _CanvasViewportBottomBar.height;

          return SizedBox(
            width: boundedWidth,
            height: boundedHeight,
            child: _CanvasEditorPanelShell(
              title: widget.selectionLabels.title,
              rightStripBar: _memoizedRightStripBar(),
              bottomBar: _memoizedBottomBar(),
              child: LayoutBuilder(
                builder: (context, viewportConstraints) {
                  final viewportSize = Size(
                    viewportConstraints.maxWidth,
                    viewportConstraints.maxHeight,
                  );
                  _rememberEditorViewportSize(viewportSize);

                  final canvasView = _buildViewportContent(context);
                  final overlayBuilder = widget.viewportOverlayBuilder;
                  final underlayBuilder = widget.viewportUnderlayBuilder;
                  final contentStrokeActive = widget.contentStrokeActive;

                  final selectionLayerActive =
                      canvasToolSelects(widget.brushToolState.tool) &&
                      widget.coordinator != null;

                  Widget gestureLayer(bool contentStrokeIsActive) {
                    return CanvasViewportGestureLayer(
                      viewport: _viewport,
                      onViewportChanged: _setViewport,
                      rotationEnabled: widget.allowViewRotation,
                      strokeActive:
                          _strokeActive ||
                          _selectionDragActive ||
                          contentStrokeIsActive,
                      // Nothing drawn in the viewport (canvas, playback
                      // frames, camera overlay) may paint outside the panel.
                      child: ClipRect(
                        child:
                            overlayBuilder == null &&
                                underlayBuilder == null &&
                                _toolTapHandler() == null &&
                                !selectionLayerActive &&
                                !_eyedropperCursorActive
                            ? canvasView
                            : Stack(
                                children: [
                                  if (underlayBuilder != null)
                                    Positioned.fill(
                                      child: underlayBuilder(
                                        context,
                                        _viewport,
                                      ),
                                    ),
                                  Positioned.fill(child: canvasView),
                                  if (overlayBuilder != null)
                                    Positioned.fill(
                                      child: overlayBuilder(context, _viewport),
                                    ),
                                  // Non-painting tools (P5 eyedropper / P6
                                  // fill): one tap layer ABOVE the canvas
                                  // absorbs the pointer so no stroke starts.
                                  if (_toolTapHandler() != null)
                                    Positioned.fill(
                                      child: Listener(
                                        key: const ValueKey<String>(
                                          'canvas-tool-tap-layer',
                                        ),
                                        behavior: HitTestBehavior.opaque,
                                        onPointerDown: (event) =>
                                            _toolTapHandler()!(
                                              _viewport.viewportToCanvas(
                                                ViewportPoint(
                                                  x: event.localPosition.dx,
                                                  y: event.localPosition.dy,
                                                ),
                                              ),
                                            ),
                                      ),
                                    ),
                                  // Eyedropper cursor (R11-②): crosshair +
                                  // a hover swatch of the color under the
                                  // pointer — for the tool AND the Alt-held
                                  // temporary pick. Translucent: picks fall
                                  // through to the tap layer / canvas below.
                                  if (_eyedropperCursorActive) ...[
                                    Positioned.fill(
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.precise,
                                        opaque: false,
                                        hitTestBehavior:
                                            HitTestBehavior.translucent,
                                        onExit: (_) =>
                                            _eyedropperHover.value = null,
                                        child: Listener(
                                          key: const ValueKey<String>(
                                            'eyedropper-hover-tracker',
                                          ),
                                          behavior: HitTestBehavior.translucent,
                                          // Hover + move only: sampling on
                                          // pointer DOWN would double the
                                          // pick tap's composite sample.
                                          onPointerHover: (event) =>
                                              _updateEyedropperHover(
                                                event.localPosition,
                                              ),
                                          onPointerMove: (event) =>
                                              _updateEyedropperHover(
                                                event.localPosition,
                                              ),
                                        ),
                                      ),
                                    ),
                                    ValueListenableBuilder<
                                      ({Offset position, int color})?
                                    >(
                                      valueListenable: _eyedropperHover,
                                      builder: (context, hover, _) {
                                        if (hover == null) {
                                          return const SizedBox.shrink();
                                        }
                                        return Positioned(
                                          left: hover.position.dx + 14,
                                          top: hover.position.dy - 34,
                                          child: IgnorePointer(
                                            child: Container(
                                              key: const ValueKey<String>(
                                                'eyedropper-hover-swatch',
                                              ),
                                              width: 26,
                                              height: 26,
                                              decoration: BoxDecoration(
                                                color: Color(
                                                  0xFF000000 | hover.color,
                                                ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black38,
                                                    blurRadius: 3,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                  // The P9 selection tools own the pointer
                                  // while active (marquee/lasso/move) —
                                  // strokes cannot start below the layer.
                                  if (selectionLayerActive)
                                    Positioned.fill(
                                      child: CanvasSelectionLayer(
                                        tool: switch (widget
                                            .brushToolState
                                            .tool) {
                                          CanvasTool.lasso =>
                                            CanvasSelectionTool.lasso,
                                          CanvasTool.move =>
                                            CanvasSelectionTool.move,
                                          _ => CanvasSelectionTool.rect,
                                        },
                                        onShapeCommitted:
                                            widget.historyManager == null ||
                                                widget.selectionCommands == null
                                            ? null
                                            : (before, after) => widget
                                                  .historyManager!
                                                  .execute(
                                                    SelectionShapeHistoryCommand(
                                                      channel: widget
                                                          .selectionCommands!,
                                                      before: before,
                                                      after: after,
                                                    ),
                                                  ),
                                        viewport: _viewport,
                                        canvasSize: widget.canvasSize,
                                        frameToken:
                                            widget.coordinator!.activeFrameKey,
                                        visibleCommands: () => widget
                                            .coordinator!
                                            .frameStore
                                            .getOrCreateFrame(
                                              widget
                                                  .coordinator!
                                                  .activeFrameKey,
                                            )
                                            .visibleActivePaintCommands,
                                        selectionCommands:
                                            widget.selectionCommands,
                                        onDragActiveChanged: (active) {
                                          if (_selectionDragActive != active) {
                                            widget.onSelectionInteractionChanged
                                                ?.call(active);
                                            setState(
                                              () =>
                                                  _selectionDragActive = active,
                                            );
                                          }
                                        },
                                        onTransformCommitted:
                                            _handleSelectionTransform,
                                        // R14-④: the Move tool lifts the
                                        // selection's PIXELS (never whole
                                        // strokes) — 유저 direction ⑧b.
                                        onLiftRequested: _handleSelectionLift,
                                        onLiftDabsRewritten:
                                            _handleLiftDabsRewritten,
                                        onLiftConfirmed: _handleLiftConfirmed,
                                        onLiftReverted: _handleLiftReverted,
                                        // Pending move sessions hold the
                                        // session's edit lock (seeks
                                        // refused) WITHOUT locking
                                        // viewport navigation.
                                        onMoveSessionPendingChanged:
                                            widget.onSelectionInteractionChanged,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    );
                  }

                  return SizedBox.expand(
                    key: const ValueKey<String>('brush-canvas-editor-viewport'),
                    // Pan/zoom input lives on the panel — not the interactive
                    // canvas — so navigation keeps working when the viewport
                    // shows the blank paper or playback instead of a frame.
                    child: contentStrokeActive == null
                        ? gestureLayer(false)
                        : ValueListenableBuilder<bool>(
                            valueListenable: contentStrokeActive,
                            builder: (context, active, _) =>
                                gestureLayer(active),
                          ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewportContent(BuildContext context) {
    final override = widget.contentOverride;
    if (override != null) {
      return override(context, _viewport);
    }

    final coordinator = widget.coordinator!;
    final activeKey = coordinator.activeFrameKey;
    final interactiveView = InteractiveBrushEditCanvasView(
      // STABLE key (R13-2): keying by frameId remounted the whole
      // interactive subtree on every frame flip — the constant flip
      // hitch. Cel changes reset in place via didUpdateWidget.
      key: const ValueKey<String>('brush-canvas-view'),
      sessionState: coordinator.activeSessionState,
      layerId: activeKey.layerId,
      frameId: activeKey.frameId,
      inputSettings: widget.brushToolState.toInputSettings(),
      viewport: _viewport,
      // Alt+click = temporary eyedropper (P5): color only, the active
      // painting tool stays.
      onAltPick: widget.sampleColorAt == null || widget.onAltColorPick == null
          ? null
          : (point) {
              final color = widget.sampleColorAt!(point);
              if (color != null) {
                widget.onAltColorPick!(color);
              }
            },
      onSourceStrokeCommitted: _handleSourceStrokeCommitted,
      onActiveStrokeChanged: (active) {
        if (_strokeActive != active) {
          widget.onStrokeInputActiveChanged?.call(active);
          setState(() => _strokeActive = active);
        }
      },
      // The underlay paints the paper (and the layers below); an opaque
      // background here would hide them.
      showTransparentBackground: widget.viewportUnderlayBuilder == null,
    );
    // The draw-through wrap: display AND hit testing share one screen
    // matrix, so the active layer draws posed and pointers inverse-map to
    // artwork coordinates in lockstep (R3 ⑩ — always-applied transforms).
    final pose = widget.interactiveContentPose;
    final Widget posedView = pose == null
        ? interactiveView
        : Transform(
            transform: layerPoseViewportWrapMatrix(
              pose.pose,
              widget.canvasSize,
              _viewport,
              anchorPoint: pose.anchorPoint,
            ),
            child: interactiveView,
          );
    if (widget.interactiveContentOpacity >= 1.0) {
      return posedView;
    }
    return Opacity(
      opacity: widget.interactiveContentOpacity.clamp(0.0, 1.0).toDouble(),
      child: posedView,
    );
  }

  void _rememberEditorViewportSize(Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    if (_editorViewportSize == size) {
      return;
    }
    _editorViewportSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _setViewport(CanvasViewport viewport) {
    setState(() => _viewport = viewport.clamped());
    _syncViewportParent();
  }

  void _setViewportDuringPanbarDrag(CanvasViewport viewport) {
    setState(() => _viewport = viewport.clamped());
  }

  void _syncViewportParent() {
    _lastWidgetViewport = _viewport;
    widget.onViewportChanged?.call(_viewport);
  }

  void _zoomAroundCenter(double factor) {
    final viewportSize = _resolvedEditorViewportSize();
    final anchor = ViewportPoint(
      x: viewportSize.width / 2,
      y: viewportSize.height / 2,
    );
    setState(() {
      _viewport = _viewport.zoomedAround(
        nextZoom: _viewport.zoom * factor,
        anchor: anchor,
      );
    });
    widget.onViewportChanged?.call(_viewport);
  }

  void _fitToView() {
    final canvasSize = widget.canvasSize;
    final focusRect = widget.fitFocusRect;
    final viewportSize = _resolvedEditorViewportSize();
    setState(() {
      _viewport = focusRect != null
          ? CanvasViewport.fitToCanvasRect(
              left: focusRect.left,
              top: focusRect.top,
              width: focusRect.width,
              height: focusRect.height,
              viewportWidth: viewportSize.width,
              viewportHeight: viewportSize.height,
            )
          : CanvasViewport.fitToView(
              canvasWidth: canvasSize.width.toDouble(),
              canvasHeight: canvasSize.height.toDouble(),
              viewportWidth: viewportSize.width,
              viewportHeight: viewportSize.height,
            );
    });
    widget.onViewportChanged?.call(_viewport);
  }

  Size _resolvedEditorViewportSize() {
    return _editorViewportSize ??
        Size(
          widget.canvasSize.width.toDouble(),
          widget.canvasSize.height.toDouble(),
        );
  }

  void _resetView() {
    _setViewport(CanvasViewport());
  }

  ViewportPoint get _viewportCenterAnchor {
    final viewportSize = _resolvedEditorViewportSize();
    return ViewportPoint(x: viewportSize.width / 2, y: viewportSize.height / 2);
  }

  /// Rotates the VIEW by [degrees] around the viewport center (P8). The
  /// result snaps to 0° when within ±0.01° (float dust from gesture
  /// accumulations must not leave the AABB slow path armed forever).
  void _rotateAroundCenter(double degrees) {
    var next = _viewport.rotationDegrees + degrees;
    final normalized = ((next + 180) % 360) - 180;
    if (normalized.abs() < 0.01) {
      next = next - normalized;
    }
    _setViewport(
      _viewport.rotatedAround(
        nextRotationDegrees: next,
        anchor: _viewportCenterAnchor,
      ),
    );
  }

  void _toggleFlipHorizontal() {
    _setViewport(_viewport.flippedAround(anchor: _viewportCenterAnchor));
  }

  /// The tap action for the active NON-PAINTING tool; null while a
  /// painting tool is active (no tap layer mounts then).
  void Function(CanvasPoint point)? _toolTapHandler() {
    switch (widget.brushToolState.tool) {
      case CanvasTool.brush:
      case CanvasTool.eraser:
      // The selection/move tools mount their own drag layer, not the tap
      // layer.
      case CanvasTool.selectRect:
      case CanvasTool.lasso:
      case CanvasTool.move:
        return null;
      case CanvasTool.eyedropper:
        final sample = widget.sampleColorAt;
        final pick = widget.onEyedropperPick;
        if (sample == null || pick == null) {
          return null;
        }
        return (point) {
          final color = sample(point);
          if (color != null) {
            pick(color);
          }
        };
      case CanvasTool.fill:
        final fill = widget.fillDabAt;
        if (fill == null || widget.coordinator == null) {
          return null;
        }
        return (point) {
          final dab = fill(point, widget.brushToolState.color);
          if (dab != null) {
            // The exact stroke funnel: history, parity and .qap
            // serialization treat the fill like any stroke ("fill = one
            // mask dab").
            _handleSourceStrokeCommitted(
              BrushStrokeCommitData(sourceDabs: [dab]),
            );
          }
        };
    }
  }

  void _handleSourceStrokeCommitted(BrushStrokeCommitData strokeData) {
    labProbe('penUpCommitHandler', () => _commitSourceStroke(strokeData));
  }

  /// R16-① bitmap lift: commits [shape]'s ERASE — RAW, outside app
  /// history (the origin must vanish instantly, but nothing is undoable
  /// until the session CONFIRMS) — and returns the command's id plus the
  /// lifted stamp dab, which floats until the confirm. Null when the
  /// shape covers no pixels.
  ({BrushPaintCommandId commandId, BrushDab stampDab})? _handleSelectionLift(
    CanvasSelectionShape shape,
  ) {
    final coordinator = widget.coordinator;
    if (coordinator == null) {
      return null;
    }
    final lift = buildSelectionLiftDabs(
      shape: shape,
      surface: coordinator.activeSessionState.canvasState.currentSurface,
      liftId: '${DateTime.now().microsecondsSinceEpoch}',
    );
    if (lift == null) {
      return null;
    }
    final command = coordinator.commitSourceStroke(
      sourceDabs: [lift.eraseDab],
      cacheInvalidationSink: widget.cacheInvalidationSink,
    );
    if (command == null) {
      return null;
    }
    setState(() {});
    return (commandId: command.id, stampDab: lift.stampDab);
  }

  /// R16-① confirm: adopts the whole move session (raw lift + landed
  /// stamp) into app history as ONE undo entry.
  void _handleLiftConfirmed(
    BrushPaintCommandId commandId,
    List<BrushDab> dabs,
  ) {
    final coordinator = widget.coordinator;
    if (coordinator == null) {
      return;
    }
    // The setState rebuilds the interactive view onto the post-confirm
    // surface (R17-①b: without it the landed stamp stayed invisible —
    // white hole at the origin, nothing at the destination — until an
    // unrelated rebuild). Mounted guard: the layer's unmount path
    // confirms post-frame, possibly after this panel went with it.
    void run() {
      final historyManager = widget.historyManager;
      if (historyManager == null) {
        coordinator.rewritePaintCommandDabs(
          {commandId: dabs},
          cacheInvalidationSink: widget.cacheInvalidationSink,
        );
        return;
      }
      historyManager.execute(
        BrushLiftMoveHistoryCommand(
          coordinator: coordinator,
          commandId: commandId,
          confirmedDabs: dabs,
          cacheInvalidationSink: widget.cacheInvalidationSink,
        ),
      );
    }

    if (mounted) {
      setState(run);
    } else {
      run();
    }
  }

  /// REVERT of a fresh session (R17-①): the raw lift is the coordinator
  /// stack's newest entry (drawing and seeks are locked while pending),
  /// so popping it restores the pre-lift picture byte-exactly.
  void _handleLiftReverted(BrushPaintCommandId commandId) {
    void run() {
      widget.coordinator?.undo(
        cacheInvalidationSink: widget.cacheInvalidationSink,
      );
    }

    if (mounted) {
      setState(run);
    } else {
      run();
    }
  }

  /// Raw lift-command dab rewrite (no history entry) — the drag lifecycle
  /// suppresses/restores the floating stamp through this. The setState
  /// matters: a rewrite swaps the session surface WITHOUT a session
  /// notify, and the interactive view must rebuild onto the new surface
  /// (R17-①b: the confirmed stamp was invisible until a frame roundtrip).
  void _handleLiftDabsRewritten(
    BrushPaintCommandId commandId,
    List<BrushDab> dabs,
  ) {
    void run() {
      widget.coordinator?.rewritePaintCommandDabs(
        {commandId: dabs},
        cacheInvalidationSink: widget.cacheInvalidationSink,
      );
    }

    if (mounted) {
      setState(run);
    } else {
      run();
    }
  }

  void _commitSourceStroke(BrushStrokeCommitData strokeData) {
    // Only reachable from the interactive canvas, which requires the
    // coordinator to exist.
    final coordinator = widget.coordinator!;
    setState(() {
      final historyManager = widget.historyManager;
      if (historyManager == null) {
        coordinator.commitSourceStroke(
          sourceDabs: strokeData.sourceDabs,
          cacheInvalidationSink: widget.cacheInvalidationSink,
          prerasterizedStrokePixels: strokeData.strokePixels,
          prerasterizedStrokeBounds: strokeData.strokeBounds,
        );
        return;
      }
      historyManager.execute(
        BrushStrokeHistoryCommand(
          coordinator: coordinator,
          strokeData: strokeData,
          cacheInvalidationSink: widget.cacheInvalidationSink,
        ),
      );
    });
  }

  /// One finished selection move (P9): ONE app-level undo entry via the
  /// in-place dab rewrite.
  void _handleSelectionTransform(CanvasSelectionTransform transform) {
    final coordinator = widget.coordinator!;
    final command = BrushSelectionTransformHistoryCommand(
      coordinator: coordinator,
      frameKey: coordinator.activeFrameKey,
      before: transform.before,
      after: transform.after,
      cacheInvalidationSink: widget.cacheInvalidationSink,
    );
    setState(() {
      final historyManager = widget.historyManager;
      if (historyManager == null) {
        command.execute();
        return;
      }
      historyManager.execute(command);
    });
  }
}

class _CanvasEditorPanelShell extends StatelessWidget {
  static const double statusStripHeight = 20;
  static const double rightStripWidth = 18;

  const _CanvasEditorPanelShell({
    required this.title,
    required this.child,
    required this.bottomBar,
    required this.rightStripBar,
  });

  final String title;
  final Widget child;
  final Widget bottomBar;
  final Widget rightStripBar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight.clamp(0.0, double.infinity).toDouble()
            : statusStripHeight + _CanvasViewportBottomBar.height;
        // The selection labels live in a slim STATUS strip right under the
        // panel frame (the canvas tab already names the panel — a
        // full-height title bar would just repeat chrome).
        final statusHeight = statusStripHeight.clamp(0.0, maxHeight).toDouble();
        final remainingHeight = (maxHeight - statusHeight)
            .clamp(0.0, double.infinity)
            .toDouble();
        final compactBottomHeight = remainingHeight == 0
            ? 0.0
            : remainingHeight * 0.45;
        final bottomRoom = compactBottomHeight
            .clamp(0.0, _CanvasViewportBottomBar.height)
            .toDouble();
        final contentHeight = (remainingHeight - bottomRoom)
            .clamp(0.0, double.infinity)
            .toDouble();

        return DecoratedBox(
          key: const ValueKey<String>('canvas-editor-panel-shell'),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            color: colorScheme.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: statusHeight,
                child: ClipRect(
                  child: Container(
                    key: const ValueKey<String>(
                      'canvas-editor-panel-status-strip',
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      border: Border(
                        bottom: BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: contentHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        key: const ValueKey<String>(
                          'canvas-editor-panel-content',
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: child,
                      ),
                    ),
                    Container(
                      key: const ValueKey<String>(
                        'canvas-editor-panel-right-strip',
                      ),
                      width: rightStripWidth,
                      alignment: Alignment.center,
                      color: colorScheme.surfaceContainerHighest,
                      child: rightStripBar,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: bottomRoom,
                child: ClipRect(
                  child: LayoutBuilder(
                    builder: (context, bottomConstraints) {
                      return OverflowBox(
                        alignment: Alignment.topCenter,
                        minWidth: bottomConstraints.maxWidth,
                        maxWidth: bottomConstraints.maxWidth,
                        minHeight: _CanvasViewportBottomBar.height,
                        maxHeight: _CanvasViewportBottomBar.height,
                        child: DecoratedBox(
                          key: const ValueKey<String>(
                            'canvas-editor-panel-bottom-bar',
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            border: Border(
                              top: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                          child: bottomBar,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CanvasViewportBottomBar extends StatelessWidget {
  static const double height = _CanvasViewportToolbar.height + 14;

  const _CanvasViewportBottomBar({
    required this.viewport,
    required this.editorViewportSize,
    required this.canvasSize,
    required this.onViewportChanged,
    required this.onViewportChangeEnd,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onReset,
    required this.onRotateCcw,
    required this.onRotateCw,
    required this.onFlipHorizontal,
  });

  final CanvasViewport viewport;
  final Size editorViewportSize;
  final CanvasSize canvasSize;
  final ValueChanged<CanvasViewport> onViewportChanged;
  final VoidCallback onViewportChangeEnd;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final VoidCallback onReset;

  /// Null hides the rotate/flip controls (rotation-disabled hosts).
  final VoidCallback? onRotateCcw;
  final VoidCallback? onRotateCw;
  final VoidCallback? onFlipHorizontal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        children: [
          _CanvasViewportToolbar(
            viewport: viewport,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onFit: onFit,
            onReset: onReset,
            onRotateCcw: onRotateCcw,
            onRotateCw: onRotateCw,
            onFlipHorizontal: onFlipHorizontal,
          ),
          CanvasViewportHorizontalScrollbar(
            viewport: viewport,
            editorViewportSize: editorViewportSize,
            canvasSize: canvasSize,
            onViewportChanged: onViewportChanged,
            onViewportChangeEnd: onViewportChangeEnd,
          ),
        ],
      ),
    );
  }
}

class _CanvasViewportToolbar extends StatelessWidget {
  static const double height = 40;

  const _CanvasViewportToolbar({
    required this.viewport,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onReset,
    required this.onRotateCcw,
    required this.onRotateCw,
    required this.onFlipHorizontal,
  });

  final CanvasViewport viewport;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final VoidCallback onReset;
  final VoidCallback? onRotateCcw;
  final VoidCallback? onRotateCw;
  final VoidCallback? onFlipHorizontal;

  @override
  Widget build(BuildContext context) {
    final zoomPercent = (viewport.zoom * 100).round();
    // Normalized for display: multi-turn accumulation shows as its
    // visible angle.
    final rotationDegrees = (((viewport.rotationDegrees + 180) % 360) - 180)
        .round();
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          key: const ValueKey<String>('canvas-viewport-toolbar'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$zoomPercent%',
              key: const ValueKey<String>('canvas-viewport-zoom-label'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              key: const ValueKey<String>('canvas-viewport-zoom-out'),
              onPressed: onZoomOut,
              child: const Text('Zoom out'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              key: const ValueKey<String>('canvas-viewport-zoom-in'),
              onPressed: onZoomIn,
              child: const Text('Zoom in'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              key: const ValueKey<String>('canvas-viewport-fit'),
              onPressed: onFit,
              child: const Text('Fit'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              key: const ValueKey<String>('canvas-viewport-reset'),
              onPressed: onReset,
              child: const Text('Reset'),
            ),
            if (onRotateCcw != null) ...[
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey<String>('canvas-viewport-rotate-ccw'),
                tooltip: 'Rotate View Left',
                onPressed: onRotateCcw,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.rotate_left),
              ),
            ],
            if (onRotateCw != null)
              IconButton(
                key: const ValueKey<String>('canvas-viewport-rotate-cw'),
                tooltip: 'Rotate View Right',
                onPressed: onRotateCw,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.rotate_right),
              ),
            if (onFlipHorizontal != null)
              IconButton(
                key: const ValueKey<String>('canvas-viewport-flip'),
                tooltip: 'Flip View Horizontal',
                onPressed: onFlipHorizontal,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                isSelected: viewport.flipHorizontal,
                icon: const Icon(Icons.flip),
              ),
            if (rotationDegrees != 0)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '$rotationDegrees°',
                  key: const ValueKey<String>('canvas-viewport-rotation-label'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CanvasEditorSelectionLabels {
  const CanvasEditorSelectionLabels({
    this.projectLabel = '-',
    this.cutLabel = '-',
    this.layerLabel = '-',
    this.frameLabel = '-',
  });

  final String projectLabel;
  final String cutLabel;
  final String layerLabel;
  final String frameLabel;

  String get title =>
      'Project: $projectLabel · Cut: $cutLabel · Layer: $layerLabel · Frame: $frameLabel';
}

class CanvasViewportHorizontalScrollbar extends StatelessWidget {
  const CanvasViewportHorizontalScrollbar({
    super.key,
    required this.viewport,
    required this.editorViewportSize,
    required this.canvasSize,
    required this.onViewportChanged,
    this.onViewportChangeEnd,
  });
  final CanvasViewport viewport;
  final Size editorViewportSize;
  final CanvasSize canvasSize;
  final ValueChanged<CanvasViewport> onViewportChanged;
  final VoidCallback? onViewportChangeEnd;
  @override
  Widget build(BuildContext context) => _CanvasViewportPanbar(
    axis: Axis.horizontal,
    viewport: viewport,
    editorViewportSize: editorViewportSize,
    canvasSize: canvasSize,
    onViewportChanged: onViewportChanged,
    onViewportChangeEnd: onViewportChangeEnd,
  );
}

class CanvasViewportVerticalScrollbar extends StatelessWidget {
  const CanvasViewportVerticalScrollbar({
    super.key,
    required this.viewport,
    required this.editorViewportSize,
    required this.canvasSize,
    required this.onViewportChanged,
    this.onViewportChangeEnd,
  });
  final CanvasViewport viewport;
  final Size editorViewportSize;
  final CanvasSize canvasSize;
  final ValueChanged<CanvasViewport> onViewportChanged;
  final VoidCallback? onViewportChangeEnd;
  @override
  Widget build(BuildContext context) => _CanvasViewportPanbar(
    axis: Axis.vertical,
    viewport: viewport,
    editorViewportSize: editorViewportSize,
    canvasSize: canvasSize,
    onViewportChanged: onViewportChanged,
    onViewportChangeEnd: onViewportChangeEnd,
  );
}

class _CanvasViewportPanbar extends StatefulWidget {
  const _CanvasViewportPanbar({
    required this.axis,
    required this.viewport,
    required this.editorViewportSize,
    required this.canvasSize,
    required this.onViewportChanged,
    this.onViewportChangeEnd,
  });
  final Axis axis;
  final CanvasViewport viewport;
  final Size editorViewportSize;
  final CanvasSize canvasSize;
  final ValueChanged<CanvasViewport> onViewportChanged;
  final VoidCallback? onViewportChangeEnd;

  @override
  State<_CanvasViewportPanbar> createState() => _CanvasViewportPanbarState();
}

class _CanvasViewportPanbarState extends State<_CanvasViewportPanbar> {
  double? _dragStartThumbStart;
  double? _dragStartPointerAxisPosition;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.axis == Axis.horizontal;
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackExtent = isHorizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        return GestureDetector(
          key: ValueKey<String>(
            isHorizontal
                ? 'canvas-viewport-horizontal-scrollbar'
                : 'canvas-viewport-vertical-scrollbar',
          ),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: isHorizontal
              ? (details) => _dragStart(details.localPosition.dx, trackExtent)
              : null,
          onVerticalDragStart: isHorizontal
              ? null
              : (details) => _dragStart(details.localPosition.dy, trackExtent),
          onHorizontalDragUpdate: isHorizontal
              ? (details) => _dragUpdate(details.localPosition.dx, trackExtent)
              : null,
          onVerticalDragUpdate: isHorizontal
              ? null
              : (details) => _dragUpdate(details.localPosition.dy, trackExtent),
          onHorizontalDragEnd: isHorizontal ? (_) => _dragEnd() : null,
          onVerticalDragEnd: isHorizontal ? null : (_) => _dragEnd(),
          onHorizontalDragCancel: isHorizontal ? _dragEnd : null,
          onVerticalDragCancel: isHorizontal ? null : _dragEnd,
          child: SizedBox(
            height: isHorizontal ? 14 : double.infinity,
            width: isHorizontal ? double.infinity : 14,
            child: CustomPaint(
              painter: _CanvasViewportPanbarPainter(
                axis: widget.axis,
                viewport: widget.viewport,
                editorViewportSize: widget.editorViewportSize,
                canvasSize: widget.canvasSize,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }

  void _dragStart(double pointerAxisPosition, double trackExtent) {
    final metrics = CanvasViewportPanMetrics(
      axis: widget.axis,
      viewport: widget.viewport,
      editorViewportSize: widget.editorViewportSize,
      canvasSize: widget.canvasSize,
      trackExtent: trackExtent,
    );

    _dragStartThumbStart = metrics.thumbStart;
    _dragStartPointerAxisPosition = pointerAxisPosition;
  }

  void _dragUpdate(double pointerAxisPosition, double trackExtent) {
    final dragStartThumbStart = _dragStartThumbStart;
    final dragStartPointerAxisPosition = _dragStartPointerAxisPosition;
    if (dragStartThumbStart == null || dragStartPointerAxisPosition == null) {
      return;
    }

    final metrics = CanvasViewportPanMetrics(
      axis: widget.axis,
      viewport: widget.viewport,
      editorViewportSize: widget.editorViewportSize,
      canvasSize: widget.canvasSize,
      trackExtent: trackExtent,
    );

    if (!metrics.canScroll) {
      return;
    }

    final pointerDelta = pointerAxisPosition - dragStartPointerAxisPosition;
    final nextThumbStart = (dragStartThumbStart + pointerDelta)
        .clamp(0.0, metrics.thumbTravel)
        .toDouble();

    // panToThumb only moves THIS panbar's axis and already lands inside
    // the scrollable range. Never clamp the other axis here: the canvas
    // pans freely (a zoomed-in paper may sit at a positive pan), and a
    // both-axes clamp used to snap the paper left-aligned the moment the
    // vertical bar was touched.
    widget.onViewportChanged(metrics.panToThumb(nextThumbStart));
  }

  void _dragEnd() {
    _dragStartThumbStart = null;
    _dragStartPointerAxisPosition = null;
    widget.onViewportChangeEnd?.call();
  }
}

class _CanvasViewportPanbarPainter extends CustomPainter {
  const _CanvasViewportPanbarPainter({
    required this.axis,
    required this.viewport,
    required this.editorViewportSize,
    required this.canvasSize,
    required this.color,
  });
  final Axis axis;
  final CanvasViewport viewport;
  final Size editorViewportSize;
  final CanvasSize canvasSize;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final isHorizontal = axis == Axis.horizontal;
    final trackExtent = isHorizontal ? size.width : size.height;
    final metrics = CanvasViewportPanMetrics(
      axis: axis,
      viewport: viewport,
      editorViewportSize: editorViewportSize,
      canvasSize: canvasSize,
      trackExtent: trackExtent,
    );
    final thumbStart = metrics.thumbStart;
    final trackPaint = Paint()..color = color.withValues(alpha: 0.16);
    final thumbPaint = Paint()..color = color.withValues(alpha: 0.72);
    final track = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(7)),
      trackPaint,
    );
    final thumb = isHorizontal
        ? Rect.fromLTWH(thumbStart, 0, metrics.thumbExtent, size.height)
        : Rect.fromLTWH(0, thumbStart, size.width, metrics.thumbExtent);
    canvas.drawRRect(
      RRect.fromRectAndRadius(thumb, const Radius.circular(7)),
      thumbPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CanvasViewportPanbarPainter oldDelegate) =>
      oldDelegate.viewport != viewport ||
      oldDelegate.editorViewportSize != editorViewportSize ||
      oldDelegate.canvasSize != canvasSize ||
      oldDelegate.color != color;
}
