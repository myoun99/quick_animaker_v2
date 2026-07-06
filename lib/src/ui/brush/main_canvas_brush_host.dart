import 'package:flutter/material.dart';

import '../../models/brush_frame_key.dart';
import '../playback/playback_frame_painter.dart';
import '../../models/brush_history_policy.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';
import '../../services/brush_frame_edit_session_store.dart';
import '../../services/brush_frame_store.dart';
import '../../services/brush_frame_editing_coordinator.dart';
import '../../services/cache_invalidation_executor.dart';
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
    this.frameStore,
    this.cacheInvalidationSink,
    this.historyManager,
    this.viewport,
    this.onViewportChanged,
    this.selectionLabels = const CanvasEditorSelectionLabels(),
    this.brushToolState = BrushToolState.defaults,
    this.viewportOverlayBuilder,
    this.contentOverride,
  });

  final BrushFrameKey? activeFrameKey;
  final BrushEditorSelection? selection;
  final List<BrushFrameKey>? availableFrameKeys;
  final CanvasSize canvasSize;

  /// Injectable stroke store (the session-owned one in production, so
  /// app-level commands can transform stroke data); defaults to a local one.
  final BrushFrameStore? frameStore;

  /// Injectable invalidation sink (the session hub in production, so
  /// playback caches hear about stroke edits); defaults to a local recorder.
  final CacheInvalidationSink? cacheInvalidationSink;

  final HistoryManager? historyManager;
  final CanvasViewport? viewport;
  final ValueChanged<CanvasViewport>? onViewportChanged;
  final CanvasEditorSelectionLabels selectionLabels;
  final BrushToolState brushToolState;

  /// Forwarded to [BrushCanvasPanel]: stacked over the canvas inside the
  /// editor viewport (e.g. the camera frame overlay).
  final Widget Function(BuildContext context, CanvasViewport viewport)?
  viewportOverlayBuilder;

  /// Forwarded to [BrushCanvasPanel]: replaces the interactive canvas inside
  /// the panel shell (playback). Without an editable frame the host supplies
  /// its own blank-canvas override, so the paper always shows.
  final Widget Function(BuildContext context, CanvasViewport viewport)?
  contentOverride;

  BrushFrameKey? get resolvedActiveFrameKey =>
      activeFrameKey ?? selection?.toBrushFrameKey();

  @override
  State<MainCanvasBrushHost> createState() => _MainCanvasBrushHostState();
}

class _MainCanvasBrushHostState extends State<MainCanvasBrushHost> {
  late final CacheInvalidationSink _cacheInvalidationSink =
      widget.cacheInvalidationSink ?? BrushEditCacheInvalidationSink();
  late final BrushFrameStore _frameStore =
      widget.frameStore ?? BrushFrameStore();

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
      // Keep the coordinator (and with it the paint commands and undo
      // history); it rebuilds the session surfaces at the new size from the
      // durable commands.
      _coordinator?.resizeCanvas(widget.canvasSize);
    }
    _selectResolvedFrame();
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = _coordinator;
    final hasEditableFrame = _frameKeys.isNotEmpty && coordinator != null;
    // No editable frame: keep the panel (and its paper) visible, just
    // without brush input — drawing needs a selected frame.
    final contentOverride =
        widget.contentOverride ??
        (hasEditableFrame ? null : _blankCanvasContent);

    return BrushCanvasPanel(
      key: const ValueKey<String>('main-canvas-brush-host'),
      coordinator: hasEditableFrame ? coordinator : null,
      availableFrameKeys: _frameKeys,
      cacheInvalidationSink: _cacheInvalidationSink,
      canvasSize: widget.canvasSize,
      historyManager: widget.historyManager,
      viewport: widget.viewport,
      onViewportChanged: widget.onViewportChanged,
      selectionLabels: widget.selectionLabels,
      brushToolState: widget.brushToolState,
      viewportOverlayBuilder: widget.viewportOverlayBuilder,
      contentOverride: contentOverride,
    );
  }

  Widget _blankCanvasContent(BuildContext context, CanvasViewport viewport) {
    return CustomPaint(
      key: const ValueKey<String>('main-canvas-brush-host-blank-canvas'),
      painter: PlaybackFramePainter(
        image: null,
        canvasSize: widget.canvasSize,
        viewport: viewport,
      ),
      child: const SizedBox.expand(),
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
