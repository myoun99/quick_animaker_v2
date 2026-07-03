import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/brush_frame_key.dart';
import '../../models/brush_paint_command.dart';
import '../../models/canvas_size.dart';
import '../../services/brush_frame_display_cache_renderer.dart';
import '../../services/brush_frame_display_cache_service.dart';
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
  late BrushFrameDisplayCacheService _displayCacheService =
      _createDisplayCacheService();
  bool _isDrawing = false;
  bool _cachePreparationScheduled = false;

  @override
  void didUpdateWidget(covariant BrushCanvasPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.coordinator != oldWidget.coordinator ||
        widget.canvasSize != oldWidget.canvasSize) {
      _displayCacheService = _createDisplayCacheService();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeKey = widget.coordinator.activeFrameKey;
    final session = widget.coordinator.activeSessionState;
    final frameStore = widget.coordinator.frameStore;
    final drawing = frameStore.getOrCreateFrame(activeKey);
    final displayPreviewSurface = frameStore.validPreviewSurfaceOrNull(
      activeKey,
    );
    if (displayPreviewSurface == null &&
        !_isDrawing &&
        drawing.visibleActivePaintCommands.isNotEmpty) {
      _scheduleDisplayCachePreparation(activeKey);
    }
    final visibleCommands = displayPreviewSurface == null
        ? drawing.visibleActivePaintCommands
        : const <BrushPaintCommand>[];
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
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
        child: SizedBox(
          width: widget.canvasSize.width.toDouble(),
          height: widget.canvasSize.height.toDouble(),
          child: InteractiveBrushEditCanvasView(
            key: ValueKey<String>('brush-canvas-${activeKey.frameId.value}'),
            sessionState: session,
            layerId: activeKey.layerId,
            frameId: activeKey.frameId,
            inputSettings: _inputSettings,
            committedSourceDabs: committedSourceDabs,
            committedSourceDabStrokes: committedSourceDabStrokes,
            displayPreviewSurface: displayPreviewSurface,
            onActiveStrokeChanged: _handleActiveStrokeChanged,
            onSourceStrokeCommitted: _handleSourceStrokeCommitted,
          ),
        ),
      ),
    );
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

  void _handleActiveStrokeChanged(bool isDrawing) {
    if (_isDrawing == isDrawing) {
      return;
    }
    setState(() {
      _isDrawing = isDrawing;
    });
  }

  BrushFrameDisplayCacheService _createDisplayCacheService() {
    return BrushFrameDisplayCacheService(
      frameStore: widget.coordinator.frameStore,
      renderer: BrushFrameDisplayCacheRenderer(canvasSize: widget.canvasSize),
    );
  }

  void _scheduleDisplayCachePreparation(BrushFrameKey key) {
    if (_cachePreparationScheduled) {
      return;
    }
    _cachePreparationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cachePreparationScheduled = false;
      if (!mounted || _isDrawing || widget.coordinator.activeFrameKey != key) {
        return;
      }
      final drawing = widget.coordinator.frameStore.getOrCreateFrame(key);
      if (drawing.visibleActivePaintCommands.isEmpty) {
        return;
      }
      final cache = _displayCacheService.prepareFramePreview(key);
      if (mounted && cache.isValid) {
        setState(() {});
      }
    });
  }
}
