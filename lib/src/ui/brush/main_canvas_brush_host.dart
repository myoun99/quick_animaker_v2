import 'package:flutter/material.dart';

import '../../models/brush_frame_key.dart';
import '../../models/brush_history_policy.dart';
import '../../services/brush_frame_edit_session_store.dart';
import '../../services/brush_frame_store.dart';
import '../../services/brush_workspace_coordinator.dart';
import 'brush_canvas_panel.dart';
import 'brush_editor_selection.dart';
import 'brush_workspace_cache_invalidation_sink.dart';
import 'brush_workspace_fixture.dart';

/// Main-canvas-oriented Brush host prepared for HomePage integration.
///
/// The HomePage preview path can now pass the active editor selection or a
/// concrete [BrushFrameKey]. The temporary fixture remains only for explicit
/// fixture/test helper use and is not a production fallback.
class MainCanvasBrushHost extends StatefulWidget {
  const MainCanvasBrushHost({
    super.key,
    this.activeFrameKey,
    this.selection,
    this.availableFrameKeys,
  }) : useFixtureFallback = false;

  MainCanvasBrushHost.fixture({super.key})
    : activeFrameKey = null,
      selection = null,
      availableFrameKeys = BrushWorkspaceFixture.createFrameKeys(),
      useFixtureFallback = true;

  final BrushFrameKey? activeFrameKey;
  final BrushEditorSelection? selection;
  final List<BrushFrameKey>? availableFrameKeys;
  final bool useFixtureFallback;

  BrushFrameKey? get resolvedActiveFrameKey =>
      activeFrameKey ?? selection?.toBrushFrameKey();

  @override
  State<MainCanvasBrushHost> createState() => _MainCanvasBrushHostState();
}

class _MainCanvasBrushHostState extends State<MainCanvasBrushHost> {
  late final _coordinator = BrushWorkspaceCoordinator(
    initialFrameKey: _frameKeys.first,
    frameStore: BrushFrameStore(),
    sessionStore: BrushFrameEditSessionStore(
      canvasSize: BrushWorkspaceFixture.canvasSize,
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
      if (!widget.useFixtureFallback) {
        return const [];
      }
      if (explicitKeys == null || explicitKeys.isEmpty) {
        return BrushWorkspaceFixture.createFrameKeys();
      }
      return List<BrushFrameKey>.unmodifiable(explicitKeys);
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
