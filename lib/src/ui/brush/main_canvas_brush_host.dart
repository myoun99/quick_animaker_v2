import 'package:flutter/material.dart';

import '../../models/brush_frame_key.dart';
import '../../models/brush_history_policy.dart';
import '../../services/brush_frame_edit_session_store.dart';
import '../../services/brush_frame_store.dart';
import '../../services/brush_workspace_coordinator.dart';
import 'brush_editor_selection.dart';
import 'brush_workspace_cache_invalidation_sink.dart';
import 'brush_workspace_fixture.dart';
import 'brush_workspace_view.dart';

/// Main-canvas-oriented Brush host prepared for HomePage integration.
///
/// The HomePage preview path can now pass the active editor selection or a
/// concrete [BrushFrameKey]. The temporary fixture remains only for tests and
/// fallback when no editor layer/frame is available.
class MainCanvasBrushHost extends StatefulWidget {
  const MainCanvasBrushHost({
    super.key,
    this.activeFrameKey,
    this.selection,
    this.availableFrameKeys,
  });

  MainCanvasBrushHost.fixture({super.key})
    : activeFrameKey = null,
      selection = null,
      availableFrameKeys = BrushWorkspaceFixture.createFrameKeys();

  final BrushFrameKey? activeFrameKey;
  final BrushEditorSelection? selection;
  final List<BrushFrameKey>? availableFrameKeys;

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
    return BrushWorkspaceView(
      key: const ValueKey<String>('main-canvas-brush-host'),
      coordinator: _coordinator,
      availableFrameKeys: _frameKeys,
      cacheInvalidationSink: _cacheInvalidationSink,
    );
  }

  List<BrushFrameKey> _resolveFrameKeys() {
    final explicitKeys = widget.availableFrameKeys;
    final activeKey = widget.resolvedActiveFrameKey;
    if (explicitKeys == null || explicitKeys.isEmpty) {
      if (activeKey == null) {
        // TODO: Remove fixture fallback after main canvas brush selection is stable.
        return BrushWorkspaceFixture.createFrameKeys();
      }
      return [activeKey];
    }
    if (activeKey == null || explicitKeys.contains(activeKey)) {
      return List<BrushFrameKey>.unmodifiable(explicitKeys);
    }
    return List<BrushFrameKey>.unmodifiable([...explicitKeys, activeKey]);
  }

  void _selectResolvedFrame() {
    final activeKey = widget.resolvedActiveFrameKey ?? _frameKeys.first;
    _coordinator.selectFrame(activeKey);
  }
}
