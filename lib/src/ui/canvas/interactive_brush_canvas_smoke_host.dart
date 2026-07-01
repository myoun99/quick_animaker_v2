import 'package:flutter/material.dart';

import '../../models/bitmap_surface.dart';
import '../../models/brush_bitmap_materialization_history_state.dart';
import '../../models/brush_edit_session_cache_operation_result.dart';
import '../../models/brush_edit_session_state.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_surface_state.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../services/cache_invalidation_executor.dart';
import 'brush_edit_canvas_input_settings.dart';
import 'interactive_brush_edit_canvas_view.dart';

class InteractiveBrushCanvasSmokeHost extends StatefulWidget {
  const InteractiveBrushCanvasSmokeHost({
    super.key,
    required this.initialSessionState,
    required this.layerId,
    required this.frameId,
    required this.inputSettings,
    required this.cacheInvalidationSink,
    this.sessionResetToken,
    this.showTransparentBackground = true,
    this.onOperationResult,
  });

  factory InteractiveBrushCanvasSmokeHost.blank({
    Key? key,
    required LayerId layerId,
    required FrameId frameId,
    required BrushEditCanvasInputSettings inputSettings,
    required CacheInvalidationSink cacheInvalidationSink,
    CanvasSize? canvasSize,
    int tileSize = 16,
    Object? sessionResetToken,
    bool showTransparentBackground = true,
    ValueChanged<BrushEditSessionCacheOperationResult>? onOperationResult,
  }) {
    final resolvedCanvasSize = canvasSize ?? CanvasSize(width: 64, height: 64);

    return InteractiveBrushCanvasSmokeHost(
      key: key,
      initialSessionState: BrushEditSessionState(
        canvasState: CanvasSurfaceState(
          currentSurface: BitmapSurface(
            canvasSize: resolvedCanvasSize,
            tileSize: tileSize,
          ),
        ),
        materializationHistoryState: BrushBitmapMaterializationHistoryState(),
      ),
      layerId: layerId,
      frameId: frameId,
      inputSettings: inputSettings,
      cacheInvalidationSink: cacheInvalidationSink,
      sessionResetToken: sessionResetToken,
      showTransparentBackground: showTransparentBackground,
      onOperationResult: onOperationResult,
    );
  }

  final BrushEditSessionState initialSessionState;
  final LayerId layerId;
  final FrameId frameId;
  final BrushEditCanvasInputSettings inputSettings;
  final CacheInvalidationSink cacheInvalidationSink;
  final Object? sessionResetToken;
  final bool showTransparentBackground;
  final ValueChanged<BrushEditSessionCacheOperationResult>? onOperationResult;

  @override
  State<InteractiveBrushCanvasSmokeHost> createState() =>
      _InteractiveBrushCanvasSmokeHostState();
}

class _InteractiveBrushCanvasSmokeHostState
    extends State<InteractiveBrushCanvasSmokeHost> {
  late BrushEditSessionState _sessionState;

  @override
  void initState() {
    super.initState();
    _sessionState = widget.initialSessionState;
  }

  @override
  void didUpdateWidget(covariant InteractiveBrushCanvasSmokeHost oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(widget.sessionResetToken, oldWidget.sessionResetToken)) {
      _sessionState = widget.initialSessionState;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBrushEditCanvasView(
      key: const ValueKey<String>('interactive-brush-canvas-smoke-host-view'),
      sessionState: _sessionState,
      layerId: widget.layerId,
      frameId: widget.frameId,
      inputSettings: widget.inputSettings,
      cacheInvalidationSink: widget.cacheInvalidationSink,
      showTransparentBackground: widget.showTransparentBackground,
      onOperationResult: _handleOperationResult,
    );
  }

  void _handleOperationResult(BrushEditSessionCacheOperationResult result) {
    setState(() {
      _sessionState = result.sessionState;
    });
    widget.onOperationResult?.call(result);
  }
}
