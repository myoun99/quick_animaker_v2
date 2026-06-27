import 'package:flutter/material.dart';

import '../../models/brush_edit_session_cache_operation_result.dart';
import '../../models/brush_frame_key.dart';
import '../../models/brush_history_policy.dart';
import '../../models/cache_invalidation_execution_result.dart';
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
import '../../services/brush_frame_store.dart';
import '../../services/brush_workspace_coordinator.dart';
import '../../services/cache_invalidation_executor.dart';
import '../canvas/brush_edit_canvas_input_settings.dart';
import '../canvas/interactive_brush_edit_canvas_view.dart';

class BrushWorkspaceScreen extends StatefulWidget {
  const BrushWorkspaceScreen({super.key});

  @override
  State<BrushWorkspaceScreen> createState() => _BrushWorkspaceScreenState();
}

class _BrushWorkspaceScreenState extends State<BrushWorkspaceScreen> {
  static const _projectId = ProjectId('brush-workspace-project');
  static const _trackId = TrackId('brush-workspace-track');
  static const _cutId = CutId('brush-workspace-cut');
  static const _layerId = LayerId('brush-workspace-layer');
  static const _canvasSize = CanvasSize(width: 320, height: 240);

  late final List<BrushFrameKey> _frameKeys;
  late final BrushWorkspaceCoordinator _coordinator;
  final _cacheInvalidationSink = _BrushWorkspaceCacheInvalidationSink();
  var _inputSettings = const BrushEditCanvasInputSettings(size: 10);

  @override
  void initState() {
    super.initState();
    _frameKeys =
        const [FrameId('frame-1'), FrameId('frame-2'), FrameId('frame-3')]
            .map((frameId) {
              return BrushFrameKey(
                projectId: _projectId,
                trackId: _trackId,
                cutId: _cutId,
                layerId: _layerId,
                frameId: frameId,
              );
            })
            .toList(growable: false);
    _coordinator = BrushWorkspaceCoordinator(
      initialFrameKey: _frameKeys.first,
      frameStore: BrushFrameStore(),
      sessionStore: BrushFrameEditSessionStore(canvasSize: _canvasSize),
      historyPolicy: const BrushHistoryPolicy(
        userUndoLimit: 24,
        deferredBakeRatio: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeKey = _coordinator.activeFrameKey;
    final activeIndex = _frameKeys.indexOf(activeKey) + 1;
    final session = _coordinator.activeSessionState;
    final frameState = _coordinator.frameStore.getOrCreateFrame(activeKey);

    return Scaffold(
      appBar: AppBar(title: const Text('Brush Workspace')),
      body: Padding(
        key: const ValueKey<String>('brush-workspace-screen'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < _frameKeys.length; i += 1)
                  FilledButton.tonal(
                    key: ValueKey<String>('brush-frame-${i + 1}-button'),
                    onPressed: () =>
                        setState(() => _coordinator.selectFrame(_frameKeys[i])),
                    child: Text('Frame ${i + 1}'),
                  ),
                TextButton(
                  key: const ValueKey<String>('brush-workspace-undo-button'),
                  onPressed: _coordinator.undoHistory.undoStack.isEmpty
                      ? null
                      : () => setState(
                          () => _coordinator.undo(
                            cacheInvalidationSink: _cacheInvalidationSink,
                          ),
                        ),
                  child: const Text('Undo'),
                ),
                TextButton(
                  key: const ValueKey<String>('brush-workspace-redo-button'),
                  onPressed: _coordinator.undoHistory.redoStack.isEmpty
                      ? null
                      : () => setState(
                          () => _coordinator.redo(
                            cacheInvalidationSink: _cacheInvalidationSink,
                          ),
                        ),
                  child: const Text('Redo'),
                ),
                TextButton(
                  key: const ValueKey<String>('brush-workspace-reset-button'),
                  onPressed: () => setState(
                    () => _coordinator.sessionStore.reset(activeKey),
                  ),
                  child: const Text('Reset Session'),
                ),
                _ColorButton(
                  label: 'Black',
                  color: Colors.black,
                  selected: _inputSettings.color == 0xFF000000,
                  onPressed: () => setState(
                    () => _inputSettings = _inputSettings.copyWith(
                      color: 0xFF000000,
                    ),
                  ),
                ),
                _ColorButton(
                  label: 'Red',
                  color: Colors.red,
                  selected: _inputSettings.color == 0xFFFF0000,
                  onPressed: () => setState(
                    () => _inputSettings = _inputSettings.copyWith(
                      color: 0xFFFF0000,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Active Frame: Frame $activeIndex (${activeKey.frameId.value})',
              key: const ValueKey<String>('brush-workspace-active-frame-label'),
            ),
            Text(
              'Commands: ${frameState.paintCommands.length} | Live: ${_coordinator.liveCommandCount(activeKey)} | Undo: ${_coordinator.undoHistory.undoStack.length} | Redo: ${_coordinator.undoHistory.redoStack.length}',
              key: const ValueKey<String>('brush-workspace-status-text'),
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
              child: SizedBox(
                width: _canvasSize.width.toDouble(),
                height: _canvasSize.height.toDouble(),
                child: InteractiveBrushEditCanvasView(
                  key: ValueKey<String>(
                    'brush-canvas-${activeKey.frameId.value}',
                  ),
                  sessionState: session,
                  layerId: activeKey.layerId,
                  frameId: activeKey.frameId,
                  inputSettings: _inputSettings,
                  cacheInvalidationSink: _cacheInvalidationSink,
                  onOperationResult: _handleOperationResult,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleOperationResult(BrushEditSessionCacheOperationResult result) {
    setState(() => _coordinator.applyBrushOperationResult(result));
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(Icons.circle, color: color, size: 14),
    label: Text(selected ? '$label ✓' : label),
  );
}

class _BrushWorkspaceCacheInvalidationSink implements CacheInvalidationSink {
  final layerTiles = <LayerTileCacheKey>[];
  final frameComposites = <FrameCompositeCacheKey>[];
  final playbackPreviews = <PlaybackPreviewCacheKey>[];

  CacheInvalidationExecutionResult get latestResult =>
      CacheInvalidationExecutionResult(
        layerTileCount: layerTiles.length,
        frameCompositeCount: frameComposites.length,
        playbackPreviewCount: playbackPreviews.length,
      );

  @override
  void invalidateFrameComposite(FrameCompositeCacheKey key) =>
      frameComposites.add(key);
  @override
  void invalidateLayerTile(LayerTileCacheKey key) => layerTiles.add(key);
  @override
  void invalidatePlaybackPreview(PlaybackPreviewCacheKey key) =>
      playbackPreviews.add(key);
}
