import 'package:flutter/material.dart';

import '../../models/brush_frame_key.dart';
import '../../models/brush_history_policy.dart';
import '../../services/brush_frame_edit_session_store.dart';
import '../../services/brush_frame_store.dart';
import '../../services/brush_frame_editing_coordinator.dart';
import 'brush_canvas_panel.dart';
import 'brush_editor_selection.dart';
import 'brush_workspace_cache_invalidation_sink.dart';
import 'brush_canvas_defaults.dart';

/// Main-canvas-oriented Brush host prepared for HomePage integration.
///
/// The HomePage preview path can pass the active editor selection or a
/// concrete [BrushFrameKey]. Missing selection renders a safe placeholder
/// instead of constructing test fixture data.
class MainCanvasBrushHost extends StatefulWidget {
  const MainCanvasBrushHost({
    super.key,
    this.activeFrameKey,
    this.selection,
    this.availableFrameKeys,
  });

  final BrushFrameKey? activeFrameKey;
  final BrushEditorSelection? selection;
  final List<BrushFrameKey>? availableFrameKeys;
  BrushFrameKey? get resolvedActiveFrameKey =>
      activeFrameKey ?? selection?.toBrushFrameKey();

  @override
  State<MainCanvasBrushHost> createState() => _MainCanvasBrushHostState();
}

class _MainCanvasBrushHostState extends State<MainCanvasBrushHost> {
  late final _coordinator = BrushFrameEditingCoordinator(
    initialFrameKey: _frameKeys.first,
    frameStore: BrushFrameStore(),
    sessionStore: BrushFrameEditSessionStore(
      canvasSize: BrushCanvasDefaults.canvasSize,
    ),
    historyPolicy: const BrushHistoryPolicy(
      userUndoLimit: 24,
      deferredBakeRatio: 0,
    ),
  );
  final _cacheInvalidationSink = BrushWorkspaceCacheInvalidationSink();

  late List<BrushFrameKey> _frameKeys = _resolveFrameKeys();

  @override
  void initState() {
    super.initState();
    _selectResolvedFrame();
  }

  @override
  void didUpdateWidget(covariant MainCanvasBrushHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _frameKeys = _resolveFrameKeys();
    _selectResolvedFrame();
  }

  @override
  Widget build(BuildContext context) {
    if (_frameKeys.isEmpty) {
      return const Center(
        key: ValueKey<String>('main-canvas-brush-host-empty-selection'),
        child: Text('Select a layer and frame to edit with Brush Preview.'),
      );
    }

    return BrushCanvasPanel(
      key: const ValueKey<String>('main-canvas-brush-host'),
      coordinator: _coordinator,
      availableFrameKeys: _frameKeys,
      cacheInvalidationSink: _cacheInvalidationSink,
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
    _coordinator.selectFrame(activeKey);
  }
}
