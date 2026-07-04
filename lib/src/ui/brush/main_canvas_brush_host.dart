import 'package:flutter/material.dart';

import '../../models/brush_frame_key.dart';
import '../../models/brush_history_policy.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';
import '../../services/brush_frame_edit_session_store.dart';
import '../../services/brush_frame_store.dart';
import '../../services/brush_frame_editing_coordinator.dart';
import '../../services/history_manager.dart';
import 'brush_canvas_panel.dart';
import 'brush_editor_selection.dart';
import 'brush_tool_state.dart';
import 'brush_edit_cache_invalidation_sink.dart';
import 'brush_canvas_defaults.dart';

/// Production main-canvas Brush host for HomePage integration.
///
/// The editor passes the active selection or a concrete [BrushFrameKey]. Missing
/// selection renders a safe placeholder instead of constructing fake editable
/// state. Drawing payload ownership remains in the coordinator/store boundary.
class MainCanvasBrushHost extends StatefulWidget {
  const MainCanvasBrushHost({
    super.key,
    this.activeFrameKey,
    this.selection,
    this.availableFrameKeys,
    this.canvasSize = BrushCanvasDefaults.canvasSize,
    this.historyManager,
    this.viewport,
    this.onViewportChanged,
    this.selectionLabels = const CanvasEditorSelectionLabels(),
    this.brushToolState = BrushToolState.defaults,
  });

  final BrushFrameKey? activeFrameKey;
  final BrushEditorSelection? selection;
  final List<BrushFrameKey>? availableFrameKeys;
  final CanvasSize canvasSize;
  final HistoryManager? historyManager;
  final CanvasViewport? viewport;
  final ValueChanged<CanvasViewport>? onViewportChanged;
  final CanvasEditorSelectionLabels selectionLabels;
  final BrushToolState brushToolState;
  BrushFrameKey? get resolvedActiveFrameKey =>
      activeFrameKey ?? selection?.toBrushFrameKey();

  @override
  State<MainCanvasBrushHost> createState() => _MainCanvasBrushHostState();
}

class _MainCanvasBrushHostState extends State<MainCanvasBrushHost> {
  final _cacheInvalidationSink = BrushEditCacheInvalidationSink();
  final _frameStore = BrushFrameStore();

  late List<BrushFrameKey> _frameKeys = _resolveFrameKeys();
  BrushFrameEditingCoordinator? _coordinator;

  @override
  void initState() {
    super.initState();
    _selectResolvedFrame();
  }

  @override
  void didUpdateWidget(covariant MainCanvasBrushHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _frameKeys = _resolveFrameKeys();
    if (widget.canvasSize != oldWidget.canvasSize) {
      _coordinator = null;
    }
    _selectResolvedFrame();
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = _coordinator;
    if (_frameKeys.isEmpty || coordinator == null) {
      return const Center(
        key: ValueKey<String>('main-canvas-brush-host-empty-selection'),
        child: Text('Select a layer and frame to edit with Brush.'),
      );
    }

    return BrushCanvasPanel(
      key: const ValueKey<String>('main-canvas-brush-host'),
      coordinator: coordinator,
      availableFrameKeys: _frameKeys,
      cacheInvalidationSink: _cacheInvalidationSink,
      canvasSize: widget.canvasSize,
      historyManager: widget.historyManager,
      viewport: widget.viewport,
      onViewportChanged: widget.onViewportChanged,
      selectionLabels: widget.selectionLabels,
      brushToolState: widget.brushToolState,
    );
  }

  List<BrushFrameKey> _resolveFrameKeys() {
    final explicitKeys = widget.availableFrameKeys;
    final activeKey = widget.resolvedActiveFrameKey;
    if (activeKey == null) {
      return const [];
    }
    if (explicitKeys == null || explicitKeys.isEmpty) {
      return [activeKey];
    }
    if (explicitKeys.contains(activeKey)) {
      return List<BrushFrameKey>.unmodifiable(explicitKeys);
    }
    return List<BrushFrameKey>.unmodifiable([...explicitKeys, activeKey]);
  }

  void _selectResolvedFrame() {
    if (_frameKeys.isEmpty) {
      return;
    }
    final activeKey = widget.resolvedActiveFrameKey ?? _frameKeys.first;
    final coordinator = _coordinator;
    if (coordinator == null) {
      _coordinator = _createCoordinator(initialFrameKey: activeKey);
      return;
    }
    coordinator.selectFrame(activeKey);
  }

  BrushFrameEditingCoordinator _createCoordinator({
    required BrushFrameKey initialFrameKey,
  }) {
    return BrushFrameEditingCoordinator(
      initialFrameKey: initialFrameKey,
      frameStore: _frameStore,
      sessionStore: BrushFrameEditSessionStore(canvasSize: widget.canvasSize),
      historyPolicy: const BrushHistoryPolicy(
        userUndoLimit: 24,
        deferredBakeRatio: 0,
      ),
    );
  }
}
