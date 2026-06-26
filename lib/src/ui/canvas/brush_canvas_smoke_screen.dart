import 'package:flutter/material.dart';

import '../../models/brush_edit_session_cache_operation_result.dart';
import '../../models/canvas_size.dart';
import '../../models/frame_composite_cache_key.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../models/layer_tile_cache_key.dart';
import '../../models/playback_preview_cache_key.dart';
import '../../services/cache_invalidation_executor.dart';
import 'brush_edit_canvas_input_settings.dart';
import 'interactive_brush_canvas_smoke_host.dart';

class BrushCanvasSmokeScreen extends StatefulWidget {
  const BrushCanvasSmokeScreen({
    super.key,
    this.layerId = const LayerId('smoke-layer'),
    this.frameId = const FrameId('smoke-frame'),
    this.inputSettings = const BrushEditCanvasInputSettings(),
    this.canvasSize,
    this.tileSize = 16,
    this.showTransparentBackground = true,
    this.showDebugStatus = true,
  });

  final LayerId layerId;
  final FrameId frameId;
  final BrushEditCanvasInputSettings inputSettings;
  final CanvasSize? canvasSize;
  final int tileSize;
  final bool showTransparentBackground;
  final bool showDebugStatus;

  @override
  State<BrushCanvasSmokeScreen> createState() => _BrushCanvasSmokeScreenState();
}

class _BrushCanvasSmokeScreenState extends State<BrushCanvasSmokeScreen> {
  final _cacheInvalidationSink = _RecordingCacheInvalidationSink();
  BrushEditSessionCacheOperationResult? _latestOperationResult;

  @override
  Widget build(BuildContext context) {
    final resolvedCanvasSize =
        widget.canvasSize ?? CanvasSize(width: 64, height: 64);

    return RepaintBoundary(
      key: const ValueKey<String>('brush-canvas-smoke-screen'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InteractiveBrushCanvasSmokeHost.blank(
            key: const ValueKey<String>('brush-canvas-smoke-screen-host'),
            layerId: widget.layerId,
            frameId: widget.frameId,
            inputSettings: widget.inputSettings,
            cacheInvalidationSink: _cacheInvalidationSink,
            canvasSize: resolvedCanvasSize,
            tileSize: widget.tileSize,
            showTransparentBackground: widget.showTransparentBackground,
            onOperationResult: _handleOperationResult,
          ),
          if (widget.showDebugStatus)
            Text(
              _debugStatusText,
              key: const ValueKey<String>(
                'brush-canvas-smoke-screen-debug-status',
              ),
            ),
        ],
      ),
    );
  }

  String get _debugStatusText {
    final operation = _latestOperationResult?.kind.name ?? 'none';
    return 'operation: $operation, '
        'cacheInvalidations: ${_cacheInvalidationSink.totalCalls}';
  }

  void _handleOperationResult(BrushEditSessionCacheOperationResult result) {
    setState(() {
      _latestOperationResult = result;
    });
  }
}

class _RecordingCacheInvalidationSink implements CacheInvalidationSink {
  final layerTiles = <LayerTileCacheKey>[];
  final frameComposites = <FrameCompositeCacheKey>[];
  final playbackPreviews = <PlaybackPreviewCacheKey>[];

  int get totalCalls =>
      layerTiles.length + frameComposites.length + playbackPreviews.length;

  @override
  void invalidateLayerTile(LayerTileCacheKey key) {
    layerTiles.add(key);
  }

  @override
  void invalidateFrameComposite(FrameCompositeCacheKey key) {
    frameComposites.add(key);
  }

  @override
  void invalidatePlaybackPreview(PlaybackPreviewCacheKey key) {
    playbackPreviews.add(key);
  }
}
