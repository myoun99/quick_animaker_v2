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
  });

  final BrushFrameEditingCoordinator coordinator;
  final List<BrushFrameKey> availableFrameKeys;
  final CacheInvalidationSink cacheInvalidationSink;
  final CanvasSize canvasSize;
  final BrushEditCanvasInputSettings initialInputSettings;
  final HistoryManager? historyManager;

  @override
  State<BrushCanvasPanel> createState() => _BrushCanvasPanelState();
}

class _BrushCanvasPanelState extends State<BrushCanvasPanel> {
  late final _inputSettings = widget.initialInputSettings;
  CanvasViewport _viewport = CanvasViewport();
  Size? _editorViewportSize;

  @override
  Widget build(BuildContext context) {
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
                    _CanvasViewportToolbar.height;

          return SizedBox(
            width: boundedWidth,
            height: boundedHeight,
            child: _CanvasEditorPanelShell(
              title: 'Canvas · Cut ${activeKey.frameId.value} · '
                  'Layer ${activeKey.layerId.value}',
              bottomBar: _CanvasViewportToolbar(
                viewport: _viewport,
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
                      onViewportChanged: (viewport) {
                        setState(() => _viewport = viewport);
                      },
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
    _editorViewportSize = size;
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
  }

  Size _resolvedEditorViewportSize() {
    return _editorViewportSize ??
        Size(
          widget.canvasSize.width.toDouble(),
          widget.canvasSize.height.toDouble(),
        );
  }

  void _resetView() {
    setState(() => _viewport = CanvasViewport());
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
  });

  final String title;
  final Widget child;
  final Widget bottomBar;

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
                  key: const ValueKey<String>('canvas-editor-panel-right-strip'),
                  width: rightStripWidth,
                  alignment: Alignment.center,
                  color: colorScheme.surfaceContainerHighest,
                  child: const RotatedBox(
                    quarterTurns: 1,
                    child: Text('Pan'),
                  ),
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
