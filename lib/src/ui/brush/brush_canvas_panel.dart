import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/brush_stroke_commit_data.dart';
import '../../models/brush_frame_key.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';
import '../../models/viewport_point.dart';
import '../../services/brush_frame_editing_coordinator.dart';
import '../../services/commands/brush_stroke_history_command.dart';
import '../../services/cache_invalidation_executor.dart';
import '../../services/history_manager.dart';
import '../canvas/canvas_viewport_gesture_layer.dart';
import '../canvas/interactive_brush_edit_canvas_view.dart';
import '../canvas/layer_pose_paint.dart';
import 'brush_canvas_defaults.dart';
import 'brush_tool_state.dart';
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

  CanvasAutoFrameRequest? _pendingAutoFrame;

  @override
  void didUpdateWidget(covariant BrushCanvasPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
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
  /// fit, its top-left edge wins.
  CanvasViewport _viewportRevealing(Rect rect, Size viewportSize) {
    const margin = 24.0;
    final zoom = _viewport.zoom;
    var panX = _viewport.panX;
    var panY = _viewport.panY;
    if (rect.bottom * zoom + panY > viewportSize.height - margin) {
      panY = viewportSize.height - margin - rect.bottom * zoom;
    }
    if (rect.top * zoom + panY < margin) {
      panY = margin - rect.top * zoom;
    }
    if (rect.right * zoom + panX > viewportSize.width - margin) {
      panX = viewportSize.width - margin - rect.right * zoom;
    }
    if (rect.left * zoom + panX < margin) {
      panX = margin - rect.left * zoom;
    }
    return _viewport.copyWith(panX: panX, panY: panY);
  }

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
              rightStripBar: CanvasViewportVerticalScrollbar(
                viewport: _viewport,
                editorViewportSize: _resolvedEditorViewportSize(),
                canvasSize: widget.canvasSize,
                onViewportChanged: _setViewportDuringPanbarDrag,
                onViewportChangeEnd: _syncViewportParent,
              ),
              bottomBar: _CanvasViewportBottomBar(
                viewport: _viewport,
                editorViewportSize: _resolvedEditorViewportSize(),
                canvasSize: widget.canvasSize,
                onViewportChanged: _setViewportDuringPanbarDrag,
                onViewportChangeEnd: _syncViewportParent,
                onZoomIn: () => _zoomAroundCenter(1.25),
                onZoomOut: () => _zoomAroundCenter(0.8),
                onFit: _fitToView,
                onReset: _resetView,
              ),
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

                  Widget gestureLayer(bool contentStrokeIsActive) {
                    return CanvasViewportGestureLayer(
                      viewport: _viewport,
                      onViewportChanged: _setViewport,
                      strokeActive: _strokeActive || contentStrokeIsActive,
                      // Nothing drawn in the viewport (canvas, playback
                      // frames, camera overlay) may paint outside the panel.
                      child: ClipRect(
                        child: overlayBuilder == null && underlayBuilder == null
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
      key: ValueKey<String>('brush-canvas-${activeKey.frameId.value}'),
      sessionState: coordinator.activeSessionState,
      layerId: activeKey.layerId,
      frameId: activeKey.frameId,
      inputSettings: widget.brushToolState.toInputSettings(),
      viewport: _viewport,
      onSourceStrokeCommitted: _handleSourceStrokeCommitted,
      onActiveStrokeChanged: (active) {
        if (_strokeActive != active) {
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

  void _handleSourceStrokeCommitted(BrushStrokeCommitData strokeData) {
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
  });

  final CanvasViewport viewport;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final zoomPercent = (viewport.zoom * 100).round();
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
