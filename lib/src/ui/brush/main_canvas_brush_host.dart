import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/brush_frame_key.dart';
import '../playback/playback_frame_painter.dart';
import '../../models/brush_history_policy.dart';
import '../../models/canvas_point.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';
import '../../services/brush_frame_edit_session_store.dart';
import '../../services/brush_frame_store.dart';
import '../../services/brush_frame_editing_coordinator.dart';
import '../../services/cache_invalidation_executor.dart';
import '../../services/history_manager.dart';
import '../canvas/layer_pose_paint.dart';
import 'brush_canvas_panel.dart';
import 'brush_editor_selection.dart';
import 'canvas_selection_commands.dart';
import 'canvas_view_commands.dart';
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
    this.viewportUnderlayBuilder,
    this.interactiveContentOpacity = 1.0,
    this.interactiveContentPose,
    this.contentOverride,
    this.fitFocusRect,
    this.sampleColorAt,
    this.onEyedropperPick,
    this.onAltColorPick,
    this.fillDabAt,
    this.viewCommands,
    this.selectionCommands,
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

  /// Forwarded to [BrushCanvasPanel]: painted under the interactive canvas
  /// (paper + layers below the active one).
  final Widget Function(BuildContext context, CanvasViewport viewport)?
  viewportUnderlayBuilder;

  /// Forwarded to [BrushCanvasPanel]: the active layer's display opacity.
  final double interactiveContentOpacity;

  /// Forwarded to [BrushCanvasPanel]: the active layer's pose sample (the
  /// draw-through wrap; null = identity).
  final LayerPoseSample? interactiveContentPose;

  /// Forwarded to [BrushCanvasPanel]: replaces the interactive canvas inside
  /// the panel shell (playback). Without an editable frame the host supplies
  /// its own blank-canvas override, so the paper always shows.
  final Widget Function(BuildContext context, CanvasViewport viewport)?
  contentOverride;

  /// Forwarded to [BrushCanvasPanel]: canvas-space rect the Fit button
  /// frames instead of the whole canvas.
  final Rect? fitFocusRect;

  /// Forwarded to [BrushCanvasPanel]: the P5 eyedropper's composite sampler
  /// and pick handlers, and the P6 fill dab builder.
  final int? Function(CanvasPoint point)? sampleColorAt;
  final ValueChanged<int>? onEyedropperPick;
  final ValueChanged<int>? onAltColorPick;
  final BrushDab? Function(CanvasPoint point, int color)? fillDabAt;

  /// Forwarded to [BrushCanvasPanel]: the P8 rotate/flip shortcut channel.
  final CanvasViewCommands? viewCommands;

  /// Forwarded to [BrushCanvasPanel]: the P9 selection shortcut channel.
  final CanvasSelectionCommands? selectionCommands;

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
      viewportUnderlayBuilder: widget.viewportUnderlayBuilder,
      interactiveContentOpacity: widget.interactiveContentOpacity,
      interactiveContentPose: widget.interactiveContentPose,
      contentOverride: contentOverride,
      fitFocusRect: widget.fitFocusRect,
      sampleColorAt: widget.sampleColorAt,
      onEyedropperPick: widget.onEyedropperPick,
      onAltColorPick: widget.onAltColorPick,
      fillDabAt: widget.fillDabAt,
      viewCommands: widget.viewCommands,
      selectionCommands: widget.selectionCommands,
    );
  }

  Widget _blankCanvasContent(BuildContext context, CanvasViewport viewport) {
    // With an underlay the paper AND the layers below the active one are
    // already painted underneath — drawing another opaque paper here buried
    // them (the "artwork exists but the canvas shows blank paper" bug
    // whenever the active layer had no frame at the playhead). Only the
    // standalone case paints its own paper.
    if (widget.viewportUnderlayBuilder != null) {
      return const SizedBox.expand(
        key: ValueKey<String>('main-canvas-brush-host-blank-canvas'),
      );
    }
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
