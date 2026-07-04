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
import '../canvas/brush_edit_canvas_input_settings.dart';
import '../canvas/interactive_brush_edit_canvas_view.dart';
import 'brush_canvas_defaults.dart';

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
    this.initialInputSettings = const BrushEditCanvasInputSettings(size: 10),
    this.historyManager,
    this.viewport,
    this.onViewportChanged,
    this.selectionLabels = const CanvasEditorSelectionLabels(),
  });

  final BrushFrameEditingCoordinator coordinator;
  final List<BrushFrameKey> availableFrameKeys;
  final CacheInvalidationSink cacheInvalidationSink;
  final CanvasSize canvasSize;
  final BrushEditCanvasInputSettings initialInputSettings;
  final HistoryManager? historyManager;
  final CanvasViewport? viewport;
  final ValueChanged<CanvasViewport>? onViewportChanged;
  final CanvasEditorSelectionLabels selectionLabels;

  @override
  State<BrushCanvasPanel> createState() => _BrushCanvasPanelState();
}

class _BrushCanvasPanelState extends State<BrushCanvasPanel> {
  late final _inputSettings = widget.initialInputSettings;
  late CanvasViewport _viewport = widget.viewport ?? CanvasViewport();
  Size? _editorViewportSize;

  @override
  Widget build(BuildContext context) {
    if (widget.viewport != null && widget.viewport != _viewport) {
      _viewport = widget.viewport!;
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
                onViewportChanged: _setViewport,
              ),
              bottomBar: _CanvasViewportBottomBar(
                viewport: _viewport,
                editorViewportSize: _resolvedEditorViewportSize(),
                canvasSize: widget.canvasSize,
                onViewportChanged: _setViewport,
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
                      inputSettings: _inputSettings,
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
    return DecoratedBox(
      key: const ValueKey<String>('canvas-editor-panel-shell'),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surface,
      ),
      child: Column(
        children: [
          Container(
            key: const ValueKey<String>('canvas-editor-panel-title-bar'),
            height: topBarHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: colorScheme.surfaceContainerHighest,
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    key: const ValueKey<String>('canvas-editor-panel-content'),
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
          DecoratedBox(
            key: const ValueKey<String>('canvas-editor-panel-bottom-bar'),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: bottomBar,
          ),
        ],
      ),
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
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onReset,
  });

  final CanvasViewport viewport;
  final Size editorViewportSize;
  final CanvasSize canvasSize;
  final ValueChanged<CanvasViewport> onViewportChanged;
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
  const CanvasViewportHorizontalScrollbar({super.key, required this.viewport, required this.editorViewportSize, required this.canvasSize, required this.onViewportChanged});
  final CanvasViewport viewport;
  final Size editorViewportSize;
  final CanvasSize canvasSize;
  final ValueChanged<CanvasViewport> onViewportChanged;
  @override
  Widget build(BuildContext context) => _CanvasViewportPanbar(axis: Axis.horizontal, viewport: viewport, editorViewportSize: editorViewportSize, canvasSize: canvasSize, onViewportChanged: onViewportChanged);
}

class CanvasViewportVerticalScrollbar extends StatelessWidget {
  const CanvasViewportVerticalScrollbar({super.key, required this.viewport, required this.editorViewportSize, required this.canvasSize, required this.onViewportChanged});
  final CanvasViewport viewport;
  final Size editorViewportSize;
  final CanvasSize canvasSize;
  final ValueChanged<CanvasViewport> onViewportChanged;
  @override
  Widget build(BuildContext context) => _CanvasViewportPanbar(axis: Axis.vertical, viewport: viewport, editorViewportSize: editorViewportSize, canvasSize: canvasSize, onViewportChanged: onViewportChanged);
}

class _CanvasViewportPanbar extends StatelessWidget {
  const _CanvasViewportPanbar({required this.axis, required this.viewport, required this.editorViewportSize, required this.canvasSize, required this.onViewportChanged});
  final Axis axis;
  final CanvasViewport viewport;
  final Size editorViewportSize;
  final CanvasSize canvasSize;
  final ValueChanged<CanvasViewport> onViewportChanged;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = axis == Axis.horizontal;
    return GestureDetector(
      key: ValueKey<String>(isHorizontal ? 'canvas-viewport-horizontal-scrollbar' : 'canvas-viewport-vertical-scrollbar'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: isHorizontal ? (details) => _drag(details.delta.dx) : null,
      onVerticalDragUpdate: isHorizontal ? null : (details) => _drag(details.delta.dy),
      child: SizedBox(
        height: isHorizontal ? 14 : double.infinity,
        width: isHorizontal ? double.infinity : 14,
        child: CustomPaint(
          painter: _CanvasViewportPanbarPainter(axis: axis, viewport: viewport, editorViewportSize: editorViewportSize, canvasSize: canvasSize, color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  void _drag(double delta) {
    final scaledExtent = (axis == Axis.horizontal ? canvasSize.width : canvasSize.height) * viewport.zoom;
    final viewportExtent = axis == Axis.horizontal ? editorViewportSize.width : editorViewportSize.height;
    final trackExtent = (axis == Axis.horizontal ? editorViewportSize.width : editorViewportSize.height).clamp(1.0, double.infinity);
    final maxScroll = (scaledExtent - viewportExtent).clamp(0.0, double.infinity);
    final thumbExtent = maxScroll == 0 ? trackExtent : (viewportExtent / scaledExtent * trackExtent).clamp(24.0, trackExtent);
    final travel = (trackExtent - thumbExtent).clamp(1.0, double.infinity);
    final panDelta = -(delta / travel) * maxScroll;
    onViewportChanged(axis == Axis.horizontal ? viewport.copyWith(panX: viewport.panX + panDelta) : viewport.copyWith(panY: viewport.panY + panDelta));
  }
}

class _CanvasViewportPanbarPainter extends CustomPainter {
  const _CanvasViewportPanbarPainter({required this.axis, required this.viewport, required this.editorViewportSize, required this.canvasSize, required this.color});
  final Axis axis;
  final CanvasViewport viewport;
  final Size editorViewportSize;
  final CanvasSize canvasSize;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final isHorizontal = axis == Axis.horizontal;
    final trackExtent = isHorizontal ? size.width : size.height;
    final viewportExtent = isHorizontal ? editorViewportSize.width : editorViewportSize.height;
    final scaledExtent = (isHorizontal ? canvasSize.width : canvasSize.height) * viewport.zoom;
    final maxScroll = (scaledExtent - viewportExtent).clamp(0.0, double.infinity);
    final thumbExtent = maxScroll == 0 ? trackExtent : (viewportExtent / scaledExtent * trackExtent).clamp(24.0, trackExtent);
    final travel = (trackExtent - thumbExtent).clamp(0.0, double.infinity);
    final pan = isHorizontal ? viewport.panX : viewport.panY;
    final scroll = (-pan).clamp(0.0, maxScroll);
    final thumbStart = maxScroll == 0 ? 0.0 : scroll / maxScroll * travel;
    final trackPaint = Paint()..color = color.withOpacity(0.16);
    final thumbPaint = Paint()..color = color.withOpacity(0.72);
    final track = Offset.zero & size;
    canvas.drawRRect(RRect.fromRectAndRadius(track, const Radius.circular(7)), trackPaint);
    final thumb = isHorizontal ? Rect.fromLTWH(thumbStart, 0, thumbExtent, size.height) : Rect.fromLTWH(0, thumbStart, size.width, thumbExtent);
    canvas.drawRRect(RRect.fromRectAndRadius(thumb, const Radius.circular(7)), thumbPaint);
  }
  @override
  bool shouldRepaint(covariant _CanvasViewportPanbarPainter oldDelegate) => oldDelegate.viewport != viewport || oldDelegate.editorViewportSize != editorViewportSize || oldDelegate.canvasSize != canvasSize || oldDelegate.color != color;
}
