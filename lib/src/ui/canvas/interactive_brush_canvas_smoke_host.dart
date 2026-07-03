import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/brush_edit_session_state.dart';
import '../../models/brush_frame_key.dart';
import '../../models/canvas_size.dart';
import '../../models/cut_id.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../models/project_id.dart';
import '../../models/track_id.dart';
import '../../services/brush_frame_edit_session_store.dart';
import '../../services/cache_invalidation_executor.dart';
import 'brush_edit_canvas_input_settings.dart';
import 'interactive_brush_edit_canvas_view.dart';

class InteractiveBrushCanvasSmokeHost extends StatefulWidget {
  const InteractiveBrushCanvasSmokeHost({
    super.key,
    required this.initialSessionState,
    required this.layerId,
    required this.frameId,
    required this.inputSettings,
    required this.cacheInvalidationSink,
    this.committedSourceDabs = const <BrushDab>[],
    this.onSourceStrokeCommitted,
    this.sessionResetToken,
    this.showTransparentBackground = true,
  });

  factory InteractiveBrushCanvasSmokeHost.blank({
    Key? key,
    required LayerId layerId,
    required FrameId frameId,
    required BrushEditCanvasInputSettings inputSettings,
    required CacheInvalidationSink cacheInvalidationSink,
    CanvasSize? canvasSize,
    int tileSize = 16,
    Object? sessionResetToken,
    bool showTransparentBackground = true,
    List<BrushDab> committedSourceDabs = const <BrushDab>[],
    ValueChanged<List<BrushDab>>? onSourceStrokeCommitted,
  }) {
    final resolvedCanvasSize = canvasSize ?? CanvasSize(width: 64, height: 64);
    final sessionStore = BrushFrameEditSessionStore(
      canvasSize: resolvedCanvasSize,
      tileSize: tileSize,
    );
    final frameKey = BrushFrameKey(
      projectId: const ProjectId('smoke-project'),
      trackId: const TrackId('smoke-track'),
      cutId: const CutId('smoke-cut'),
      layerId: layerId,
      frameId: frameId,
    );

    return InteractiveBrushCanvasSmokeHost(
      key: key,
      initialSessionState: sessionStore.getOrCreate(frameKey),
      layerId: layerId,
      frameId: frameId,
      inputSettings: inputSettings,
      cacheInvalidationSink: cacheInvalidationSink,
      committedSourceDabs: committedSourceDabs,
      onSourceStrokeCommitted: onSourceStrokeCommitted,
      sessionResetToken: sessionResetToken,
      showTransparentBackground: showTransparentBackground,
    );
  }

  final BrushEditSessionState initialSessionState;
  final LayerId layerId;
  final FrameId frameId;
  final BrushEditCanvasInputSettings inputSettings;
  final CacheInvalidationSink cacheInvalidationSink;
  final List<BrushDab> committedSourceDabs;
  final ValueChanged<List<BrushDab>>? onSourceStrokeCommitted;
  final Object? sessionResetToken;
  final bool showTransparentBackground;

  @override
  State<InteractiveBrushCanvasSmokeHost> createState() =>
      _InteractiveBrushCanvasSmokeHostState();
}

class _InteractiveBrushCanvasSmokeHostState
    extends State<InteractiveBrushCanvasSmokeHost> {
  late BrushEditSessionState _sessionState;

  @override
  void initState() {
    super.initState();
    _sessionState = widget.initialSessionState;
  }

  @override
  void didUpdateWidget(covariant InteractiveBrushCanvasSmokeHost oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(widget.sessionResetToken, oldWidget.sessionResetToken)) {
      _sessionState = widget.initialSessionState;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBrushEditCanvasView(
      key: const ValueKey<String>('interactive-brush-canvas-smoke-host-view'),
      sessionState: _sessionState,
      layerId: widget.layerId,
      frameId: widget.frameId,
      inputSettings: widget.inputSettings,
      activeEditCompositeSurface: _sessionState.canvasState.currentSurface,
      committedSourceDabs: widget.committedSourceDabs,
      showTransparentBackground: widget.showTransparentBackground,
      onSourceStrokeCommitted: widget.onSourceStrokeCommitted ?? (_) {},
    );
  }
}
