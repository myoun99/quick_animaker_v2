import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyEvent;

import '../../services/brush_stroke_commit_data.dart';
import '../../models/bitmap_surface.dart';
import '../../models/brush_dab.dart';
import '../../models/brush_frame_key.dart';
import '../../services/canvas_selection.dart';
import '../../models/canvas_point.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';
import '../../models/viewport_point.dart';
import '../../services/brush_frame_editing_coordinator.dart';
import '../../services/commands/brush_lift_move_history_command.dart';
import '../../services/commands/brush_stroke_history_command.dart';
import '../../services/cache_invalidation_executor.dart';
import '../../services/history_manager.dart';
import '../canvas/canvas_selection_layer.dart';
import '../canvas/canvas_viewport_gesture_layer.dart';
import '../theme/app_theme.dart' show AppColors;
import '../canvas/interactive_brush_edit_canvas_view.dart';
import '../canvas/layer_pose_paint.dart';
import 'brush_canvas_defaults.dart';
import 'brush_tool_state.dart';
import '../dev_profile.dart';
import 'canvas_selection_commands.dart';
import 'selection_shape_history_command.dart';
import 'canvas_view_commands.dart';
import 'canvas_viewport_pan_metrics.dart';
import '../widgets/app_scrollbar.dart';
import '../widgets/drag_value_label.dart';

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
    this.onTemporaryToolHold,
    this.onTemporaryToolRelease,
    this.onInvokeAction,
    this.onBrushSizeDragStart,
    this.onBrushSizeDragUpdate,
    this.onBrushSizeDragEnd,
    this.onEyedropperPick,
    this.onAltColorPick,
    this.fillDabAt,
    this.selectionMaskOptions,
    this.viewCommands,
    this.selectionCommands,
    this.onStrokeInputActiveChanged,
    this.onSelectionInteractionChanged,
    this.allowViewRotation = true,
    this.statusStripActions = const <Widget>[],
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

  /// Host commands rendered right-aligned in the panel's status strip
  /// (UI-R10 #18); always visible — the title ellipsizes first.
  final List<Widget> statusStripActions;

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

  /// PEN-7a: the mapped-hold tool switch (canvas right/wheel-click
  /// mappings) — threaded through to the workspace's tool notifier.
  final void Function(CanvasTool tool)? onTemporaryToolHold;
  final void Function({required bool keep})? onTemporaryToolRelease;

  /// PEN-7b: control-mode touch slots — the flip action funnel and the
  /// brush-size drag protocol.
  final void Function(String actionId)? onInvokeAction;
  final VoidCallback? onBrushSizeDragStart;
  final void Function(double upwardDelta, {required bool snap})?
  onBrushSizeDragUpdate;
  final VoidCallback? onBrushSizeDragEnd;

  /// Builds the fill-region dab for a tap (P6); the panel commits it
  /// through the exact stroke funnel. Null disables the fill tool.
  final BrushDab? Function(CanvasPoint point, int color)? fillDabAt;

  /// R26 (C2): the Select tool's lift-time mask knobs — read at lift.
  /// Null/absent keeps the classic byte-preserving hard mask.
  final ValueListenable<SelectionMaskOptions>? selectionMaskOptions;

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

  /// R26 #23: the pointer position for tool cursors that draw an ICON but
  /// sample nothing (the fill bucket).
  final ValueNotifier<Offset?> _toolCursorHover = ValueNotifier<Offset?>(null);

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
    _toolCursorHover.dispose();
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

  /// R26 #23: the fill tool's own cursor icon (no sampling involved).
  bool get _fillCursorActive =>
      widget.brushToolState.tool == CanvasTool.fill && !_eyedropperCursorActive;

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
      toggleFlipVertical: _toggleFlipVertical,
      resetRotation: _resetRotation,
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
  ({
    CanvasViewport viewport,
    Size viewportSize,
    CanvasSize canvasSize,
    bool rotation,
    String title,
  })?
  _shellBarsToken;
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
      onZoomSet: _setZoomFromLabel,
      onFit: _fitToView,
      onReset: _resetView,
      onRotateCcw: widget.allowViewRotation ? _rotateCcwFromBar : null,
      onRotateCw: widget.allowViewRotation ? _rotateCwFromBar : null,
      onRotateReset: widget.allowViewRotation ? _resetRotation : null,
      onRotateByDrag: widget.allowViewRotation ? _rotateByDrag : null,
      onFlipHorizontal: widget.allowViewRotation ? _toggleFlipHorizontal : null,
      onFlipVertical: widget.allowViewRotation ? _toggleFlipVertical : null,
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
              actions: widget.statusStripActions,
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

                  // R26 #15: selection works with NO frame under the
                  // playhead too — the region is view state, and every
                  // pixel op (lift/fill/draw-inside) already guards the
                  // missing coordinator itself.
                  final selectionLayerActive = canvasToolSelects(
                    widget.brushToolState.tool,
                  );

                  Widget gestureLayer(bool contentStrokeIsActive) {
                    return CanvasViewportGestureLayer(
                      viewport: _viewport,
                      onViewportChanged: _setViewport,
                      rotationEnabled: widget.allowViewRotation,
                      // PEN-7b: the control-mode touch slots — flip
                      // dispatches shell actions, brush size drives the
                      // tool state (both threaded from the workspace).
                      onInvokeAction: widget.onInvokeAction,
                      onBrushSizeDragStart: widget.onBrushSizeDragStart,
                      onBrushSizeDragUpdate: widget.onBrushSizeDragUpdate,
                      onBrushSizeDragEnd: widget.onBrushSizeDragEnd,
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
                                        onPointerDown: (event) {
                                          // PRIMARY contact only (R22-B):
                                          // the middle-button pan (the
                                          // ancestor gesture layer) used
                                          // to ALSO fire the tool here —
                                          // every pan click deposited a
                                          // stray fill, which is why one
                                          // fill sometimes took two undos.
                                          if (event.buttons != kPrimaryButton) {
                                            return;
                                          }
                                          _toolTapHandler()!(
                                            _viewport.viewportToCanvas(
                                              ViewportPoint(
                                                x: event.localPosition.dx,
                                                y: event.localPosition.dy,
                                              ),
                                            ),
                                          );
                                        },
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
                                        // R26 #22: the eyedropper wears its
                                        // OWN icon, not a crosshair — the
                                        // system cursor hides and the icon
                                        // below rides the pointer.
                                        cursor: SystemMouseCursors.none,
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
                                    // R26 #22: the eyedropper ICON as the
                                    // cursor. Its tip is the hot spot, so
                                    // the glyph hangs up-left of the point
                                    // being sampled.
                                    ValueListenableBuilder<
                                      ({Offset position, int color})?
                                    >(
                                      valueListenable: _eyedropperHover,
                                      builder: (context, hover, _) {
                                        if (hover == null) {
                                          return const SizedBox.shrink();
                                        }
                                        return Positioned(
                                          left: hover.position.dx - 3,
                                          top: hover.position.dy - 21,
                                          child: const IgnorePointer(
                                            child: _ToolCursorIcon(
                                              keyValue:
                                                  'eyedropper-cursor-icon',
                                              icon: Icons.colorize,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                  // R26 #23: the fill tool wears the bucket.
                                  if (_fillCursorActive) ...[
                                    Positioned.fill(
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.none,
                                        opaque: false,
                                        hitTestBehavior:
                                            HitTestBehavior.translucent,
                                        onExit: (_) =>
                                            _toolCursorHover.value = null,
                                        child: Listener(
                                          key: const ValueKey<String>(
                                            'fill-cursor-tracker',
                                          ),
                                          behavior: HitTestBehavior.translucent,
                                          onPointerHover: (event) =>
                                              _toolCursorHover.value =
                                                  event.localPosition,
                                          onPointerMove: (event) =>
                                              _toolCursorHover.value =
                                                  event.localPosition,
                                        ),
                                      ),
                                    ),
                                    ValueListenableBuilder<Offset?>(
                                      valueListenable: _toolCursorHover,
                                      builder: (context, position, _) {
                                        if (position == null) {
                                          return const SizedBox.shrink();
                                        }
                                        return Positioned(
                                          left: position.dx - 3,
                                          top: position.dy - 20,
                                          child: const IgnorePointer(
                                            child: _ToolCursorIcon(
                                              keyValue: 'fill-cursor-icon',
                                              icon: Icons.format_color_fill,
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
                                        // R17-U: Move = 이동+변형 통합 툴
                                        // — 핸들 상시.
                                        alwaysShowTransformBox:
                                            widget.brushToolState.tool ==
                                            CanvasTool.move,
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
                                        // No frame = a stable sentinel:
                                        // the selection survives until a
                                        // real frame context arrives.
                                        frameToken:
                                            widget
                                                .coordinator
                                                ?.activeFrameKey ??
                                            'selection-no-frame',
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
                                        // R14-④: the Move tool lifts the
                                        // selection's PIXELS (never whole
                                        // strokes) — 유저 direction ⑧b.
                                        onLiftRequested: _handleSelectionLift,
                                        onLiftLanded: _handleLiftLanded,
                                        onLiftConfirmed: _handleLiftConfirmed,
                                        onLiftReverted: _handleLiftReverted,
                                        // Pending move sessions hold the
                                        // session's edit lock (seeks
                                        // refused) WITHOUT locking
                                        // viewport navigation.
                                        onMoveSessionPendingChanged: widget
                                            .onSelectionInteractionChanged,
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
      onTemporaryToolHold: widget.onTemporaryToolHold,
      onTemporaryToolRelease: widget.onTemporaryToolRelease,
      // PEN-11: one-shot mapped actions (undo/redo) from pen buttons.
      onInvokeAction: widget.onInvokeAction,
      onSourceStrokeCommitted: _handleSourceStrokeCommitted,
      // R22-A: the FILL tool runs through the view's stroke pipeline
      // (instant overlay + settling hold) instead of the panel tap layer.
      fillDabAt: widget.brushToolState.tool == CanvasTool.fill
          ? widget.fillDabAt
          : null,
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
    _zoomToAroundCenter(_viewport.zoom * factor);
  }

  /// Absolute-zoom twin of [_zoomAroundCenter] (the zoom label's inline
  /// percent entry commits through here).
  void _setZoomFromLabel(double zoom) {
    _zoomToAroundCenter(zoom);
  }

  void _zoomToAroundCenter(double nextZoom) {
    final viewportSize = _resolvedEditorViewportSize();
    final anchor = ViewportPoint(
      x: viewportSize.width / 2,
      y: viewportSize.height / 2,
    );
    setState(() {
      _viewport = _viewport.zoomedAround(nextZoom: nextZoom, anchor: anchor);
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

  void _toggleFlipVertical() {
    _setViewport(
      _viewport.flippedVerticalAround(anchor: _viewportCenterAnchor),
    );
  }

  /// Straightens the rotation to 0° around the viewport center, keeping
  /// zoom/pan/flips (UI-R18 #20).
  void _resetRotation() {
    _setViewport(
      _viewport.rotatedAround(
        nextRotationDegrees: 0,
        anchor: _viewportCenterAnchor,
      ),
    );
  }

  /// The angle-label drag (UI-R18 #21): one degree per pixel, anchored to
  /// the viewport center.
  void _rotateByDrag(double deltaDegrees) {
    _rotateAroundCenter(deltaDegrees);
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
        // R22-A: fill taps are handled by the interactive view's stroke
        // pipeline (fillDabAt) — instant overlay, settling hold, and the
        // same primary-button discipline as strokes. No tap layer.
        return null;
    }
  }

  void _handleSourceStrokeCommitted(BrushStrokeCommitData strokeData) {
    labProbe('penUpCommitHandler', () => _commitSourceStroke(strokeData));
  }

  /// Pre-lift surfaces by session token (R19 P3b): the immutable surface
  /// captured BEFORE a lift's erase — the confirm command's undo target
  /// and the revert's restore point. Reference-cheap.
  final Map<int, BitmapSurface> _liftAnchors = {};
  int _liftTokenSeq = 0;

  /// R16-① bitmap lift: commits [shape]'s ERASE — RAW, outside app
  /// history (the origin must vanish instantly, but nothing is undoable
  /// until the session CONFIRMS) — and returns a session token plus the
  /// lifted stamp dab, which floats until the confirm. Null when the
  /// shape covers no pixels.
  ({int liftToken, BrushDab stampDab})? _handleSelectionLift(
    CanvasSelectionShape shape,
  ) {
    final coordinator = widget.coordinator;
    if (coordinator == null) {
      return null;
    }
    final preLift = coordinator.currentSurfaceOf(coordinator.activeFrameKey);
    final lift = buildSelectionLiftDabs(
      shape: shape,
      surface: preLift,
      liftId: '${DateTime.now().microsecondsSinceEpoch}',
      options: widget.selectionMaskOptions?.value ?? SelectionMaskOptions.none,
    );
    if (lift == null) {
      return null;
    }
    final outcome = coordinator.commitSourceStroke(
      sourceDabs: [lift.eraseDab],
      cacheInvalidationSink: widget.cacheInvalidationSink,
    );
    if (outcome == null) {
      return null;
    }
    final token = ++_liftTokenSeq;
    _liftAnchors[token] = preLift;
    setState(() {});
    return (liftToken: token, stampDab: lift.stampDab);
  }

  /// R16-① confirm: lands the floating stamp and adopts the whole move
  /// session (raw lift + landed stamp) into app history as ONE undo
  /// entry — a surface-snapshot command whose undo target is the exact
  /// pre-lift picture (R19 P3b).
  void _handleLiftConfirmed(int liftToken, BrushDab stampDab) {
    final coordinator = widget.coordinator;
    final preLift = _liftAnchors.remove(liftToken);
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
      if (historyManager == null || preLift == null) {
        // Headless hosts (focused tests) or a lost anchor: land raw.
        coordinator.commitSourceStroke(
          sourceDabs: [stampDab],
          cacheInvalidationSink: widget.cacheInvalidationSink,
        );
        return;
      }
      historyManager.execute(
        BrushLiftMoveHistoryCommand(
          coordinator: coordinator,
          frameKey: coordinator.activeFrameKey,
          preLiftSurface: preLift,
          stampDab: stampDab,
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

  /// REVERT of a session (R17-①): the pre-lift surface snapshot restores
  /// the picture byte-exactly; nothing lands in history.
  void _handleLiftReverted(int liftToken) {
    final coordinator = widget.coordinator;
    final preLift = _liftAnchors.remove(liftToken);
    if (coordinator == null || preLift == null) {
      return;
    }
    void run() {
      coordinator.restoreSurfaceSnapshot(
        coordinator.activeFrameKey,
        preLift,
        cacheInvalidationSink: widget.cacheInvalidationSink,
      );
    }

    if (mounted) {
      setState(run);
    } else {
      run();
    }
  }

  /// Raw landing of the floating stamp (no history entry) — the abandon
  /// fallback so a reset never loses the float's pixels. The base surface
  /// is the post-erase state throughout the session, so landing is a
  /// plain stamp commit.
  void _handleLiftLanded(int liftToken, BrushDab stampDab) {
    final coordinator = widget.coordinator;
    _liftAnchors.remove(liftToken);
    if (coordinator == null) {
      return;
    }
    void run() {
      coordinator.commitSourceStroke(
        sourceDabs: [stampDab],
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
}

class _CanvasEditorPanelShell extends StatelessWidget {
  static const double statusStripHeight = 20;
  static const double rightStripWidth = 14;

  const _CanvasEditorPanelShell({
    required this.title,
    required this.child,
    required this.bottomBar,
    required this.rightStripBar,
    this.actions = const <Widget>[],
  });

  final String title;
  final Widget child;
  final Widget bottomBar;
  final Widget rightStripBar;

  /// Host commands living IN the status strip, right-aligned (UI-R10 #18
  /// — the timesheet's toolbar row retired into here). Always visible;
  /// the title text ellipsizes first when the panel narrows.
  final List<Widget> actions;

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
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ...actions,
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: contentHeight,
                child: Row(
                  children: [
                    Expanded(
                      // No inner frame (UI-R10 #16): the content box's
                      // Border.all doubled every shell line — it read as
                      // odd side padding + stray vertical lines beside the
                      // canvas. The shell's outer frame and the strips'
                      // own hairlines carry all the separation.
                      child: KeyedSubtree(
                        key: const ValueKey<String>(
                          'canvas-editor-panel-content',
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
  static const double height = 28;

  /// At/above this width the bar shows every view control (fit, 1:1,
  /// rotate, flip). Below it the secondary rotate/flip controls drop out so
  /// the essentials stay reachable (rotation is still on R/Shift+R/H).
  static const double _wideLayoutMinWidth = 360;

  /// Below this width even the essentials + zoom cluster can't share a row
  /// with a usable Expanded scrollbar, so the bar becomes horizontally
  /// scrollable instead of overflowing (slim edge docks land here).
  static const double _scrollFallbackWidth = 200;

  const _CanvasViewportBottomBar({
    required this.viewport,
    required this.editorViewportSize,
    required this.canvasSize,
    required this.onViewportChanged,
    required this.onViewportChangeEnd,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onZoomSet,
    required this.onFit,
    required this.onReset,
    required this.onRotateCcw,
    required this.onRotateCw,
    required this.onRotateReset,
    required this.onRotateByDrag,
    required this.onFlipHorizontal,
    required this.onFlipVertical,
  });

  final CanvasViewport viewport;
  final Size editorViewportSize;
  final CanvasSize canvasSize;
  final ValueChanged<CanvasViewport> onViewportChanged;
  final VoidCallback onViewportChangeEnd;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final ValueChanged<double> onZoomSet;
  final VoidCallback onFit;
  final VoidCallback onReset;

  /// Null hides the rotate/flip controls (rotation-disabled hosts).
  final VoidCallback? onRotateCcw;
  final VoidCallback? onRotateCw;
  final VoidCallback? onRotateReset;
  final ValueChanged<double>? onRotateByDrag;
  final VoidCallback? onFlipHorizontal;
  final VoidCallback? onFlipVertical;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Normalized for display: multi-turn accumulation shows as its
    // visible angle.
    final rotationDegrees = (((viewport.rotationDegrees + 180) % 360) - 180)
        .round();

    Widget divider() => Container(
      width: 1,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: colorScheme.outlineVariant,
    );

    // ROTATION/FLIP cluster (UI-R18 #20, left→right): rotate-left, the
    // ALWAYS-ON angle readout (drag = 1°/px, double-tap = type), rotate-
    // right, straighten, flip-H, flip-V. Rotate buttons accent by the
    // rotation SIGN (#18); flips accent while active (#19).
    final viewControls = <Widget>[
      if (onRotateCcw != null)
        _barIconButton(
          keyValue: 'canvas-viewport-rotate-ccw',
          tooltip: 'Rotate View Left',
          icon: const Icon(Icons.rotate_left),
          onPressed: onRotateCcw,
          isSelected: rotationDegrees < 0,
        ),
      if (onRotateByDrag != null)
        DragValueLabel(
          keyValue: 'canvas-viewport-rotation-label',
          text: '$rotationDegrees°',
          tooltip: 'View angle (drag / double-tap)',
          width: 40,
          textStyle: const TextStyle(fontSize: 11),
          onDragDelta: onRotateByDrag!,
          onEditSubmit: (text) {
            final parsed = double.tryParse(text);
            if (parsed != null && onRotateByDrag != null) {
              onRotateByDrag!(parsed - viewport.rotationDegrees);
            }
          },
        ),
      if (onRotateCw != null)
        _barIconButton(
          keyValue: 'canvas-viewport-rotate-cw',
          tooltip: 'Rotate View Right',
          icon: const Icon(Icons.rotate_right),
          onPressed: onRotateCw,
          isSelected: rotationDegrees > 0,
        ),
      if (onRotateReset != null)
        _barIconButton(
          keyValue: 'canvas-viewport-rotate-reset',
          tooltip: 'Straighten View (0°)',
          icon: const Icon(Icons.refresh),
          onPressed: onRotateReset,
        ),
      if (onFlipHorizontal != null)
        _barIconButton(
          keyValue: 'canvas-viewport-flip',
          tooltip: 'Flip View Horizontal',
          icon: const Icon(Icons.flip),
          onPressed: onFlipHorizontal,
          isSelected: viewport.flipHorizontal,
        ),
      if (onFlipVertical != null)
        _barIconButton(
          keyValue: 'canvas-viewport-flip-vertical',
          tooltip: 'Flip View Vertical',
          icon: const RotatedBox(quarterTurns: 1, child: Icon(Icons.flip)),
          onPressed: onFlipVertical,
          isSelected: viewport.flipVertical,
        ),
    ];

    // ZOOM cluster (UI-R18 #17/#20, left→right): fit, 1:1, −, the zoom
    // readout (drag = 1%/px, double-tap = type), +.
    final zoomCluster = <Widget>[
      _barIconButton(
        keyValue: 'canvas-viewport-fit',
        tooltip: 'Fit to View',
        icon: const Icon(Icons.fit_screen),
        onPressed: onFit,
      ),
      _barIconButton(
        keyValue: 'canvas-viewport-reset',
        tooltip: 'Reset View (100%)',
        icon: const Text(
          '1:1',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        onPressed: onReset,
      ),
      _barIconButton(
        keyValue: 'canvas-viewport-zoom-out',
        tooltip: 'Zoom Out',
        icon: const Icon(Icons.zoom_out),
        onPressed: onZoomOut,
      ),
      DragValueLabel(
        keyValue: 'canvas-viewport-zoom-label',
        inputKeyValue: 'canvas-viewport-zoom-input',
        text: '${(viewport.zoom * 100).round()}%',
        tooltip: 'Zoom (drag / double-tap)',
        width: 44,
        textStyle: const TextStyle(fontSize: 12),
        onDragDelta: (units) => onZoomSet(
          ((viewport.zoom * 100 + units).clamp(10.0, 1600.0)) / 100,
        ),
        onEditSubmit: (text) {
          final parsed = double.tryParse(text.replaceAll('%', '').trim());
          if (parsed != null) {
            onZoomSet(parsed.clamp(10.0, 1600.0) / 100);
          }
        },
      ),
      _barIconButton(
        keyValue: 'canvas-viewport-zoom-in',
        tooltip: 'Zoom In',
        icon: const Icon(Icons.zoom_in),
        onPressed: onZoomIn,
      ),
    ];

    Widget scrollbar() => CanvasViewportHorizontalScrollbar(
      viewport: viewport,
      editorViewportSize: editorViewportSize,
      canvasSize: canvasSize,
      onViewportChanged: onViewportChanged,
      onViewportChangeEnd: onViewportChangeEnd,
    );

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _scrollFallbackWidth) {
            // Too tight for an Expanded scrollbar between the controls —
            // scroll the whole bar so nothing overflows (slim edge docks).
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 4),
                  ...viewControls,
                  divider(),
                  SizedBox(width: 80, child: scrollbar()),
                  divider(),
                  ...zoomCluster,
                  const SizedBox(width: 4),
                ],
              ),
            );
          }
          final wide = constraints.maxWidth >= _wideLayoutMinWidth;
          return Row(
            children: [
              const SizedBox(width: 4),
              // Narrow panels drop the rotation cluster; the ZOOM cluster
              // (fit/1:1/−/%/+, UI-R18 #17/#20) always shows on the right.
              if (wide) ...viewControls,
              if (wide) divider(),
              Expanded(child: scrollbar()),
              divider(),
              ...zoomCluster,
              const SizedBox(width: 4),
            ],
          );
        },
      ),
    );
  }

  Widget _barIconButton({
    required String keyValue,
    required String tooltip,
    required Widget icon,
    required VoidCallback? onPressed,
    bool isSelected = false,
  }) {
    return IconButton(
      key: ValueKey<String>(keyValue),
      tooltip: tooltip,
      onPressed: onPressed,
      isSelected: isSelected,
      style: IconButton.styleFrom(
        minimumSize: const Size(26, 24),
        maximumSize: const Size(30, 24),
        padding: EdgeInsets.zero,
        iconSize: 18,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // UI-R21 #1: the state accent is EXPLICIT ink — the M3 isSelected
        // default was invisible in this theme, so a rotated/flipped view
        // never showed on its button. Color only (the selection rule).
        foregroundColor: isSelected ? AppColors.accent : null,
      ),
      icon: icon,
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

class _CanvasViewportPanbar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isHorizontal = axis == Axis.horizontal;
    return SizedBox(
      key: ValueKey<String>(
        isHorizontal
            ? 'canvas-viewport-horizontal-scrollbar'
            : 'canvas-viewport-vertical-scrollbar',
      ),
      height: isHorizontal ? 14 : double.infinity,
      width: isHorizontal ? double.infinity : 14,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = CanvasViewportPanMetrics(
            axis: axis,
            viewport: viewport,
            editorViewportSize: editorViewportSize,
            canvasSize: canvasSize,
            trackExtent: isHorizontal
                ? constraints.maxWidth
                : constraints.maxHeight,
          );
          return AppScrollbar(
            axis: axis,
            offset: metrics.scrollOffset,
            viewportExtent: metrics.visibleExtent,
            contentExtent: metrics.scaledContentExtent,
            minThumbExtent: CanvasViewportPanMetrics.minThumbExtent,
            // The whole lane pans relatively: the canvas panbar has always
            // been a grab-anywhere 1:1 surface, not a jump-to-tap track.
            lanePress: AppScrollbarLanePress.relativeDrag,
            onOffsetChanged: (next) =>
                onViewportChanged(metrics.viewportForScroll(next)),
            onChangeEnd: onViewportChangeEnd,
          );
        },
      ),
    );
  }
}

/// R26 #22/#23: a tool's own icon standing in for the mouse cursor —
/// white glyph with a dark halo so it reads on any artwork.
class _ToolCursorIcon extends StatelessWidget {
  const _ToolCursorIcon({required this.keyValue, required this.icon});

  final String keyValue;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: ValueKey<String>(keyValue),
      children: [
        Icon(icon, size: 22, color: Colors.black.withValues(alpha: 0.55)),
        Positioned(
          left: 1,
          top: 1,
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ],
    );
  }
}
