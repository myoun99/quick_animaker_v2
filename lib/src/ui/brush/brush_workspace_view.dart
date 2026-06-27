import 'package:flutter/material.dart';

import '../../models/brush_edit_session_cache_operation_result.dart';
import '../../models/brush_frame_key.dart';
import '../../models/canvas_size.dart';
import '../../services/brush_workspace_coordinator.dart';
import '../../services/cache_invalidation_executor.dart';
import '../canvas/brush_edit_canvas_input_settings.dart';
import '../canvas/interactive_brush_edit_canvas_view.dart';
import 'brush_workspace_fixture.dart';

/// Reusable Brush editing body extracted from [BrushWorkspaceScreen].
///
/// This widget is route-agnostic and is intended to be embedded in the main
/// editor canvas area once real timeline/layer/frame selection is wired in.
class BrushWorkspaceView extends StatefulWidget {
  const BrushWorkspaceView({
    super.key,
    required this.coordinator,
    required this.availableFrameKeys,
    required this.cacheInvalidationSink,
    this.canvasSize = BrushWorkspaceFixture.canvasSize,
    this.initialInputSettings = const BrushEditCanvasInputSettings(size: 10),
  });

  final BrushWorkspaceCoordinator coordinator;
  final List<BrushFrameKey> availableFrameKeys;
  final CacheInvalidationSink cacheInvalidationSink;
  final CanvasSize canvasSize;
  final BrushEditCanvasInputSettings initialInputSettings;

  @override
  State<BrushWorkspaceView> createState() => _BrushWorkspaceViewState();
}

class _BrushWorkspaceViewState extends State<BrushWorkspaceView> {
  late var _inputSettings = widget.initialInputSettings;

  @override
  Widget build(BuildContext context) {
    final activeKey = widget.coordinator.activeFrameKey;
    final activeIndex = widget.availableFrameKeys.indexOf(activeKey) + 1;
    final session = widget.coordinator.activeSessionState;
    final frameState = widget.coordinator.frameStore.getOrCreateFrame(
      activeKey,
    );

    return Padding(
      key: const ValueKey<String>('brush-workspace-view'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < widget.availableFrameKeys.length; i += 1)
                FilledButton.tonal(
                  key: ValueKey<String>('brush-frame-${i + 1}-button'),
                  onPressed: () => setState(
                    () => widget.coordinator.selectFrame(
                      widget.availableFrameKeys[i],
                    ),
                  ),
                  child: Text('Frame ${i + 1}'),
                ),
              TextButton(
                key: const ValueKey<String>('brush-workspace-undo-button'),
                onPressed: widget.coordinator.undoHistory.undoStack.isEmpty
                    ? null
                    : () => setState(
                        () => widget.coordinator.undo(
                          cacheInvalidationSink: widget.cacheInvalidationSink,
                        ),
                      ),
                child: const Text('Undo'),
              ),
              TextButton(
                key: const ValueKey<String>('brush-workspace-redo-button'),
                onPressed: widget.coordinator.undoHistory.redoStack.isEmpty
                    ? null
                    : () => setState(
                        () => widget.coordinator.redo(
                          cacheInvalidationSink: widget.cacheInvalidationSink,
                        ),
                      ),
                child: const Text('Redo'),
              ),
              TextButton(
                key: const ValueKey<String>('brush-workspace-reset-button'),
                onPressed: () => setState(
                  () => widget.coordinator.sessionStore.reset(activeKey),
                ),
                child: const Text('Debug Reset Session'),
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
            'Frame ${activeKey.frameId.value} commands: '
            '${frameState.paintCommands.length} total | '
            '${frameState.livePaintCommands.length} live | '
            '${frameState.hiddenByUndoPaintCommands.length} hiddenByUndo | '
            '${frameState.deferredBakePaintCommands.length} deferredBake | '
            '${widget.coordinator.undoHistory.undoStack.length} global undo | '
            '${widget.coordinator.undoHistory.redoStack.length} global redo',
            key: const ValueKey<String>('brush-workspace-status-text'),
          ),
          const Text(
            'Debug Reset Session resets only the interactive session for the '
            'active frame; it does not clear BrushFrameStore commands or '
            'UnifiedUndoHistory.',
            key: ValueKey<String>('brush-workspace-debug-reset-help'),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
            child: SizedBox(
              width: widget.canvasSize.width.toDouble(),
              height: widget.canvasSize.height.toDouble(),
              child: InteractiveBrushEditCanvasView(
                key: ValueKey<String>(
                  'brush-canvas-${activeKey.frameId.value}',
                ),
                sessionState: session,
                layerId: activeKey.layerId,
                frameId: activeKey.frameId,
                inputSettings: _inputSettings,
                cacheInvalidationSink: widget.cacheInvalidationSink,
                onOperationResult: _handleOperationResult,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleOperationResult(BrushEditSessionCacheOperationResult result) {
    setState(() => widget.coordinator.applyBrushOperationResult(result));
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
