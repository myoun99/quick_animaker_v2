import 'package:flutter/material.dart';

import '../../models/brush_edit_session_cache_operation_result.dart';
import '../../models/brush_frame_key.dart';
import '../../models/brush_history_policy.dart';
import '../../models/canvas_size.dart';
import '../../models/cut_id.dart';
import '../../models/frame_composite_cache_key.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../models/layer_tile_cache_key.dart';
import '../../models/playback_preview_cache_key.dart';
import '../../models/project_id.dart';
import '../../models/track_id.dart';
import '../../services/brush_frame_edit_session_store.dart';
import '../../services/brush_frame_editing_coordinator.dart';
import '../../services/brush_frame_store.dart';
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
  late BrushFrameEditingCoordinator _coordinator;
  late BrushEditCanvasInputSettings _inputSettings;
  late _RecordingCacheInvalidationSink _cacheInvalidationSink;
  BrushEditSessionCacheOperationResult? _latestOperationResult;
  var _sessionRevision = 0;
  String _debugOperation = 'none';

  @override
  void initState() {
    super.initState();
    _coordinator = _createCoordinator();
    _inputSettings = widget.inputSettings;
    _cacheInvalidationSink = _RecordingCacheInvalidationSink();
  }

  @override
  void didUpdateWidget(covariant BrushCanvasSmokeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.inputSettings != oldWidget.inputSettings) {
      _inputSettings = widget.inputSettings;
    }

    if (widget.canvasSize != oldWidget.canvasSize ||
        widget.tileSize != oldWidget.tileSize) {
      _resetSession(debugOperation: 'reset');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const ValueKey<String>('brush-canvas-smoke-screen'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            key: const ValueKey<String>('brush-canvas-smoke-screen-controls'),
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                key: const ValueKey<String>('brush-canvas-smoke-screen-undo'),
                onPressed: _undo,
                child: const Text('Undo'),
              ),
              TextButton(
                key: const ValueKey<String>('brush-canvas-smoke-screen-redo'),
                onPressed: _redo,
                child: const Text('Redo'),
              ),
              TextButton(
                key: const ValueKey<String>('brush-canvas-smoke-screen-reset'),
                onPressed: () => _resetSession(debugOperation: 'reset'),
                child: const Text('Reset'),
              ),
              TextButton(
                key: const ValueKey<String>(
                  'brush-canvas-smoke-screen-color-red',
                ),
                onPressed: () => _setColor(0xFFFF0000),
                child: const Text('Red'),
              ),
              TextButton(
                key: const ValueKey<String>(
                  'brush-canvas-smoke-screen-color-blue',
                ),
                onPressed: () => _setColor(0xFF0000FF),
                child: const Text('Blue'),
              ),
              TextButton(
                key: const ValueKey<String>(
                  'brush-canvas-smoke-screen-color-black',
                ),
                onPressed: () => _setColor(0xFF000000),
                child: const Text('Black'),
              ),
            ],
          ),
          InteractiveBrushCanvasSmokeHost(
            key: const ValueKey<String>('brush-canvas-smoke-screen-host'),
            initialSessionState: _coordinator.activeSessionState,
            layerId: widget.layerId,
            frameId: widget.frameId,
            inputSettings: _inputSettings,
            cacheInvalidationSink: _cacheInvalidationSink,
            sessionResetToken: _sessionRevision,
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

  CanvasSize get _resolvedCanvasSize =>
      widget.canvasSize ?? CanvasSize(width: 64, height: 64);

  BrushFrameEditingCoordinator _createCoordinator() {
    final frameKey = BrushFrameKey(
      projectId: const ProjectId('smoke-project'),
      trackId: const TrackId('smoke-track'),
      cutId: const CutId('smoke-cut'),
      layerId: widget.layerId,
      frameId: widget.frameId,
    );

    return BrushFrameEditingCoordinator(
      initialFrameKey: frameKey,
      frameStore: BrushFrameStore(),
      sessionStore: BrushFrameEditSessionStore(
        canvasSize: _resolvedCanvasSize,
        tileSize: widget.tileSize,
      ),
      historyPolicy: const BrushHistoryPolicy(
        userUndoLimit: 256,
        deferredBakeRatio: 0.1,
      ),
    );
  }

  String get _debugStatusText {
    final operation = _latestOperationResult?.kind.name ?? _debugOperation;

    return 'operation: $operation, '
        'cacheInvalidations: ${_cacheInvalidationSink.totalCalls}, '
        'color: ${_colorHex(_inputSettings.color)}';
  }

  String _colorHex(int color) =>
      '0x${color.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase()}';

  void _handleOperationResult(BrushEditSessionCacheOperationResult result) {
    setState(() {
      _coordinator.applyBrushOperationResult(result);
      _sessionRevision += 1;
      _latestOperationResult = result;
      _debugOperation = result.kind.name;
    });
  }

  void _undo() {
    setState(() {
      final entry = _coordinator.undo(
        cacheInvalidationSink: _cacheInvalidationSink,
      );
      _sessionRevision += 1;
      _latestOperationResult = null;
      _debugOperation = entry == null ? 'undo-empty' : 'undo';
    });
  }

  void _redo() {
    setState(() {
      final entry = _coordinator.redo(
        cacheInvalidationSink: _cacheInvalidationSink,
      );
      _sessionRevision += 1;
      _latestOperationResult = null;
      _debugOperation = entry == null ? 'redo-empty' : 'redo';
    });
  }

  void _resetSession({required String debugOperation}) {
    setState(() {
      _coordinator = _createCoordinator();
      _sessionRevision += 1;
      _latestOperationResult = null;
      _cacheInvalidationSink = _RecordingCacheInvalidationSink();
      _debugOperation = debugOperation;
    });
  }

  void _setColor(int color) {
    setState(() {
      _inputSettings = _inputSettings.copyWith(color: color);
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
