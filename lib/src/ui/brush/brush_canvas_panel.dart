import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/brush_frame_key.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';
import '../../models/viewport_point.dart';
import '../../services/brush_frame_editing_coordinator.dart';
import '../../services/commands/brush_stroke_history_command.dart';
import '../../services/cache_invalidation_executor.dart';
import '../../services/history_manager.dart';
import '../canvas/interactive_brush_edit_canvas_view.dart';
import 'brush_canvas_defaults.dart';
import 'brush_tool_options_bar.dart';
import 'brush_tool_state.dart';
import 'canvas_viewport_pan_metrics.dart';

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
    this.brushToolState = const BrushToolState(),
    this.onBrushToolStateChanged,
    this.historyManager,
    this.viewport,
    this.onViewportChanged,
    this.selectionLabels = const CanvasEditorSelectionLabels(),
  });

  final BrushFrameEditingCoordinator coordinator;
  final List<BrushFrameKey> availableFrameKeys;
  final CacheInvalidationSink cacheInvalidationSink;
  final CanvasSize canvasSize;
  final BrushToolState brushToolState;
  final ValueChanged<BrushToolState>? onBrushToolStateChanged;
  final HistoryManager? historyManager;
  final CanvasViewport? viewport;
  final ValueChanged<CanvasViewport>? onViewportChanged;
  final CanvasEditorSelectionLabels selectionLabels;

  @override
  State<BrushCanvasPanel> createState() => _BrushCanvasPanelState();
}

class _BrushCanvasPanelState extends State<BrushCanvasPanel> {
  late CanvasViewport _viewport = widget.viewport ?? CanvasViewport();
  CanvasViewport? _lastWidgetViewport;
  Size? _editorViewportSize;

  @override
  Widget build(BuildContext context) {
    if (widget.viewport != null && widget.viewport != _lastWidgetViewport) {
      _viewport = widget.viewport!;
      _lastWidgetViewport = widget.viewport;
    }
    final activeKey = widget.coordinator.activeFrameKey;
    final session = widget.coordinator.activeSessionState;
    final frameStore = widget.coordinator.frameStore;
    final drawing = frameStore.getOrCreateFrame(activeKey);
    final visibleCommands = drawing.visibleActivePaintCommands;
    final committedSourceDabStrokes = visibleCommands
        .map((command) => command.sourceDabs)
        .where((dabs) => dabs.isNotEmpty)
        .toList(growable: false);
    final committedSourceDabs = committedSourceDabStrokes
        .expand((dabs) => dabs)
        .toList(growable: false);

    return Padding(
      key: const ValueKey<String>('brush-canvas-panel'),
      padding: const EdgeInsets.all(16),
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
                    _CanvasEditorPanelShell.topBarHeight +
                    _CanvasEditorPanelShell.toolOptionsBarHeight +
                    _CanvasViewportBottomBar.height;

          return SizedBox(
            width: boundedWidth,
            height: boundedHeight,
            child: _CanvasEditorPanelShell(
              title: widget.selectionLabels.title,
              toolOptionsBar: BrushToolOptionsBar(
                state: widget.brushToolState,
                onChanged: widget.onBrushToolStateChanged ?? (_) {},
              ),
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

                  return SizedBox.expand(
                    key: const ValueKey<String>('brush-canvas-editor-viewport'),
                    child: InteractiveBrushEditCanvasView(
                      key: ValueKey<String>(
                        'brush-canvas-${activeKey.frameId.value}',
                      ),
                      sessionState: session,
                      layerId: activeKey.layerId,
                      frameId: activeKey.frameId,
                      inputSettings: widget.brushToolState.toInputSettings(),
                      committedSourceDabs: committedSourceDabs,
                      committedSourceDabStrokes: committedSourceDabStrokes,
                      viewport: _viewport,
                      onViewportChanged: _setViewport,
                      onSourceStrokeCommitted: _handleSourceStrokeCommitted,
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
    final viewportSize = _resolvedEditorViewportSize();
    setState(() {
      _viewport = CanvasViewport.fitToView(
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

  void _handleSourceStrokeCommitted(List<BrushDab> sourceDabs) {
    setState(() {
      final historyManager = widget.historyManager;
      if (historyManager == null) {
        widget.coordinator.commitSourceStroke(sourceDabs: sourceDabs);
        return;
      }
      historyManager.execute(
        BrushStrokeHistoryCommand(
          coordinator: widget.coordinator,
          sourceDabs: sourceDabs,
          cacheInvalidationSink: widget.cacheInvalidationSink,
        ),
      );
    });
  }
}

class _CanvasEditorPanelShell extends StatelessWidget {
  static const double topBarHeight = 32;
  static const double toolOptionsBarHeight = 44;
  static const double rightStripWidth = 18;

  const _CanvasEditorPanelShell({
    required this.title,
    required this.child,
    required this.toolOptionsBar,
    required this.bottomBar,
    required this.rightStripBar,
  });

  final String title;
  final Widget child;
  final Widget toolOptionsBar;
  final Widget bottomBar;
  final Widget rightStripBar;

  static double _remainingHeightForToolOptions(
    double maxHeight,
    double titleHeight,
  ) {
    final available = (maxHeight - titleHeight).clamp(0.0, double.infinity);
    return toolOptionsBarHeight.clamp(0.0, available).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight.clamp(0.0, double.infinity).toDouble()
            : topBarHeight + toolOptionsBarHeight + _CanvasViewportBottomBar.height;
        final titleHeight = topBarHeight.clamp(0.0, maxHeight).toDouble();
        final toolOptionsHeight = _remainingHeightForToolOptions(
          maxHeight,
          titleHeight,
        );
        final remainingHeight = (maxHeight - titleHeight - toolOptionsHeight)
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
                height: titleHeight,
                child: ClipRect(
                  child: Container(
                    key: const ValueKey<String>(
                      'canvas-editor-panel-title-bar',
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    color: colorScheme.surfaceContainerHighest,
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: toolOptionsHeight,
                child: ClipRect(child: toolOptionsBar),
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
              ? (details) => _dragUpdate(
                  details.localPosition.dx,
                  trackExtent,
                )
              : null,
          onVerticalDragUpdate: isHorizontal
              ? null
              : (details) => _dragUpdate(
                  details.localPosition.dy,
                  trackExtent,
                ),
          onHorizontalDragEnd: isHorizontal
              ? (_) => _dragEnd()
              : null,
          onVerticalDragEnd: isHorizontal
              ? null
              : (_) => _dragEnd(),
          onHorizontalDragCancel: isHorizontal
              ? _dragEnd
              : null,
          onVerticalDragCancel: isHorizontal
              ? null
              : _dragEnd,
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

    widget.onViewportChanged(
      clampCanvasViewportPan(
        viewport: metrics.panToThumb(nextThumbStart),
        editorViewportSize: widget.editorViewportSize,
        canvasSize: widget.canvasSize,
      ),
    );
  }

  void _dragEnd() {
    _dragStartThumbStart = null;
    _dragStartPointerAxisPosition = null;
    widget.onViewportChangeEnd?.call();
  }
}

CanvasViewport clampCanvasViewportPan({
  required CanvasViewport viewport,
  required Size editorViewportSize,
  required CanvasSize canvasSize,
}) {
  final horizontalMaxScroll =
      (canvasSize.width * viewport.zoom - editorViewportSize.width).clamp(
        0.0,
        double.infinity,
      );
  final verticalMaxScroll =
      (canvasSize.height * viewport.zoom - editorViewportSize.height).clamp(
        0.0,
        double.infinity,
      );
  return viewport.copyWith(
    panX: viewport.panX.clamp(-horizontalMaxScroll, 0.0).toDouble(),
    panY: viewport.panY.clamp(-verticalMaxScroll, 0.0).toDouble(),
  );
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
