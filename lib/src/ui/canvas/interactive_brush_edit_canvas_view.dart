import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/brush_dab.dart';
import '../../models/brush_edit_session_state.dart';
import '../../models/canvas_point.dart';
import '../../models/canvas_viewport.dart';
import '../../models/viewport_point.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../services/brush_dab_interpolator.dart';
import '../../services/canvas_segment_clipper.dart';
import 'active_stroke_overlay_painter.dart';
import 'bitmap_tile_image_cache.dart';
import 'brush_edit_canvas_input_settings.dart';
import 'brush_edit_canvas_view.dart';
import 'brush_tip_mask_cache.dart';

class InteractiveBrushEditCanvasView extends StatefulWidget {
  InteractiveBrushEditCanvasView({
    super.key,
    required this.sessionState,
    required this.layerId,
    required this.frameId,
    required this.inputSettings,
    required this.onSourceStrokeCommitted,
    this.dabInterpolator = const BrushDabInterpolator(),
    this.segmentClipper = const CanvasSegmentClipper(),
    this.showTransparentBackground = true,
    this.onActiveStrokeChanged,
    CanvasViewport? viewport,
    this.onViewportChanged,
  }) : viewport = viewport ?? CanvasViewport();

  final BrushEditSessionState sessionState;
  final LayerId layerId;
  final FrameId frameId;
  final BrushEditCanvasInputSettings inputSettings;
  final ValueChanged<List<BrushDab>> onSourceStrokeCommitted;
  final bool showTransparentBackground;
  final BrushDabInterpolator dabInterpolator;
  final CanvasSegmentClipper segmentClipper;
  final ValueChanged<bool>? onActiveStrokeChanged;
  final CanvasViewport viewport;
  final ValueChanged<CanvasViewport>? onViewportChanged;

  @override
  State<InteractiveBrushEditCanvasView> createState() =>
      _InteractiveBrushEditCanvasViewState();
}

class _InteractiveBrushEditCanvasViewState
    extends State<InteractiveBrushEditCanvasView> {
  /// Dabs stamped since the last flatten before the overlay is folded into
  /// [_flattenedOverlay]; keeps per-repaint and per-flatten work bounded.
  static const int _flattenBatchSize = 128;

  int? _activeDrawingPointer;
  int? _activePanPointer;
  Offset? _panStartLocalPosition;
  CanvasViewport? _panStartViewport;
  var _nextSequence = 0;
  final List<BrushDab> _collectedDabs = <BrushDab>[];
  var _breakCurrentVisibleSegment = false;
  CanvasPoint? _previousRawCanvasPosition;
  BrushEditCanvasInputSettings? _activeStrokeInputSettings;

  /// Live overlay state. Pointer moves append dabs and notify the overlay
  /// painter directly through this model — no widget rebuild per move.
  /// Older stamps are folded into the model's flattened image every
  /// [_flattenBatchSize] dabs so repaints never re-touch the whole stroke.
  final ActiveStrokeOverlayModel _overlayModel = ActiveStrokeOverlayModel();

  // After pointer-up the overlay stays visible ("settling") until the
  // committed tiles finish decoding, so the stroke never flashes away while
  // the display switches to the materialized bitmap.
  bool _settling = false;
  Timer? _settlingFallbackTimer;

  @override
  void initState() {
    super.initState();
    BitmapTileImageCache.instance.addListener(_onTileImagesChanged);
  }

  @override
  void dispose() {
    BitmapTileImageCache.instance.removeListener(_onTileImagesChanged);
    _settlingFallbackTimer?.cancel();
    _overlayModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasSize =
        widget.sessionState.canvasState.currentSurface.canvasSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : canvasSize.width.toDouble();
        final viewportHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : canvasSize.height.toDouble();

        return SizedBox(
          width: viewportWidth,
          height: viewportHeight,
          child: Listener(
            key: const ValueKey<String>(
              'interactive-brush-edit-canvas-view-listener',
            ),
            behavior: HitTestBehavior.opaque,
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,
            onPointerSignal: _handlePointerSignal,
            child: ClipRect(
              key: const ValueKey<String>('interactive-brush-edit-canvas-clip'),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: 0,
                    minHeight: 0,
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translateByDouble(
                          widget.viewport.panX,
                          widget.viewport.panY,
                          0.0,
                          1.0,
                        )
                        ..scaleByDouble(
                          widget.viewport.zoom,
                          widget.viewport.zoom,
                          1.0,
                          1.0,
                        ),
                      alignment: Alignment.topLeft,
                      child: BrushEditCanvasView(
                        sessionState: widget.sessionState,
                        showTransparentBackground:
                            widget.showTransparentBackground,
                        overlayModel: _overlayModel,
                        staleScope: (widget.layerId, widget.frameId),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_isPanButton(event.buttons)) {
      _startPan(event);
      return;
    }

    if (_activePanPointer != null ||
        _activeDrawingPointer != null ||
        !_isPrimaryButton(event.buttons)) {
      return;
    }

    final canvasPosition = _canvasPositionFromLocal(event.localPosition);
    final startsInsideSurface = _isInsideSurface(canvasPosition);

    _activeDrawingPointer = event.pointer;
    _activeStrokeInputSettings = widget.inputSettings;
    widget.onActiveStrokeChanged?.call(true);
    _nextSequence = 0;
    _breakCurrentVisibleSegment = !startsInsideSurface;
    _previousRawCanvasPosition = canvasPosition;
    _resetOverlay();
    _collectedDabs.clear();
    if (!startsInsideSurface) {
      return;
    }
    final initialDabs = widget.dabInterpolator.interpolate(
      previous: null,
      nextRaw: _dabFromPosition(canvasPosition, sequence: _nextSequence),
      firstSequence: _nextSequence,
      spacingRatio: _activeStrokeSpacing,
    );
    _collectedDabs.addAll(initialDabs);
    _overlayModel.dabs.addAll(initialDabs);
    _overlayModel.markChanged();
    _nextSequence = _collectedDabs.length;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer == _activePanPointer) {
      _updatePan(event.localPosition);
      return;
    }

    if (event.pointer != _activeDrawingPointer) {
      return;
    }

    final canvasPosition = _canvasPositionFromLocal(event.localPosition);
    final previousRaw = _previousRawCanvasPosition;
    _previousRawCanvasPosition = canvasPosition;
    if (previousRaw == null) {
      return;
    }

    final canvasSize =
        widget.sessionState.canvasState.currentSurface.canvasSize;
    final clippedSegment = widget.segmentClipper.clip(
      previous: previousRaw,
      current: canvasPosition,
      canvasSize: canvasSize,
    );
    if (clippedSegment == null) {
      _breakCurrentVisibleSegment = true;
      return;
    }

    final previousDab =
        _breakCurrentVisibleSegment ||
            clippedSegment.startsNewVisibleSegment ||
            _collectedDabs.isEmpty
        ? null
        : _collectedDabs.last;
    final segmentStartDabs =
        clippedSegment.startsNewVisibleSegment ||
            _breakCurrentVisibleSegment ||
            _collectedDabs.isEmpty
        ? widget.dabInterpolator.interpolate(
            previous: null,
            nextRaw: _dabFromPosition(
              clippedSegment.start,
              sequence: _nextSequence,
            ),
            firstSequence: _nextSequence,
            spacingRatio: _activeStrokeSpacing,
          )
        : const <BrushDab>[];
    final firstEndSequence = _nextSequence + segmentStartDabs.length;
    final endPrevious = segmentStartDabs.isNotEmpty
        ? segmentStartDabs.last
        : previousDab;
    final segmentEndDabs = widget.dabInterpolator.interpolate(
      previous: endPrevious,
      nextRaw: _dabFromPosition(clippedSegment.end, sequence: firstEndSequence),
      firstSequence: firstEndSequence,
      spacingRatio: _activeStrokeSpacing,
    );
    final addedDabCount = segmentStartDabs.length + segmentEndDabs.length;
    if (addedDabCount == 0) {
      return;
    }

    // No setState: pointer moves mutate the overlay model and repaint the
    // overlay layer directly, skipping the widget rebuild entirely (this
    // runs at pointer-sample frequency).
    if (segmentStartDabs.isNotEmpty) {
      _collectedDabs.addAll(segmentStartDabs);
      _overlayModel.dabs.addAll(segmentStartDabs);
    }
    if (segmentEndDabs.isNotEmpty) {
      _collectedDabs.addAll(segmentEndDabs);
      _overlayModel.dabs.addAll(segmentEndDabs);
    }
    _nextSequence += addedDabCount;
    _breakCurrentVisibleSegment = false;
    _maybeFlattenOverlay();
    _overlayModel.markChanged();
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer == _activePanPointer) {
      _clearPan();
      return;
    }

    if (event.pointer != _activeDrawingPointer) {
      return;
    }

    final hadDabs = _collectedDabs.isNotEmpty;
    if (hadDabs) {
      widget.onSourceStrokeCommitted(
        List<BrushDab>.unmodifiable(_collectedDabs),
      );
    }

    // Keep the overlay visible until the committed tiles decode so the
    // stroke never flashes away during the switch to the materialized
    // bitmap; the input bookkeeping is cleared immediately.
    _endStrokeInput();
    if (hadDabs) {
      _beginSettling();
    } else {
      _resetOverlay();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer == _activePanPointer) {
      _clearPan();
      return;
    }

    if (event.pointer != _activeDrawingPointer) {
      return;
    }

    _endStrokeInput();
    _resetOverlay();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        widget.onViewportChanged == null ||
        !_hasZoomModifier()) {
      return;
    }

    final factor = event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
    _emitViewport(
      widget.viewport.zoomedAround(
        nextZoom: widget.viewport.zoom * factor,
        anchor: ViewportPoint(
          x: event.localPosition.dx,
          y: event.localPosition.dy,
        ),
      ),
    );
  }

  bool _isInsideSurface(CanvasPoint localPosition) {
    final canvasSize =
        widget.sessionState.canvasState.currentSurface.canvasSize;
    return localPosition.x >= 0 &&
        localPosition.y >= 0 &&
        localPosition.x < canvasSize.width &&
        localPosition.y < canvasSize.height;
  }

  CanvasPoint _canvasPositionFromLocal(Offset localPosition) {
    return widget.viewport.viewportToCanvas(
      ViewportPoint(x: localPosition.dx, y: localPosition.dy),
    );
  }

  BrushDab _dabFromPosition(
    CanvasPoint localPosition, {
    required int sequence,
  }) {
    final settings = _activeStrokeInputSettings ?? widget.inputSettings;
    return BrushDab(
      center: localPosition,
      color: settings.color,
      size: settings.size,
      opacity: settings.opacity,
      flow: settings.flow,
      hardness: settings.hardness,
      tipShape: settings.tipShape,
      pressure: 1.0,
      sequence: sequence,
    );
  }

  double get _activeStrokeSpacing =>
      (_activeStrokeInputSettings ?? widget.inputSettings).spacing;

  bool _isPanButton(int buttons) {
    return buttons == kMiddleMouseButton;
  }

  bool _isPrimaryButton(int buttons) {
    return buttons == kPrimaryMouseButton;
  }

  void _startPan(PointerDownEvent event) {
    if (_activePanPointer != null || _activeDrawingPointer != null) {
      return;
    }
    _activePanPointer = event.pointer;
    _panStartLocalPosition = event.localPosition;
    _panStartViewport = widget.viewport;
  }

  void _updatePan(Offset localPosition) {
    final startPosition = _panStartLocalPosition;
    final startViewport = _panStartViewport;
    if (startPosition == null || startViewport == null) {
      return;
    }
    final delta = localPosition - startPosition;
    _emitViewport(startViewport.translated(dx: delta.dx, dy: delta.dy));
  }

  void _clearPan() {
    _activePanPointer = null;
    _panStartLocalPosition = null;
    _panStartViewport = null;
  }

  bool _hasZoomModifier() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
  }

  void _emitViewport(CanvasViewport viewport) {
    widget.onViewportChanged?.call(viewport.clamped());
  }

  void _endStrokeInput() {
    widget.onActiveStrokeChanged?.call(false);
    _activeDrawingPointer = null;
    _nextSequence = 0;
    _breakCurrentVisibleSegment = false;
    _previousRawCanvasPosition = null;
    _activeStrokeInputSettings = null;
    _collectedDabs.clear();
  }

  /// Clears the visible overlay (live or settling) and its flattened image.
  void _resetOverlay() {
    _settling = false;
    _settlingFallbackTimer?.cancel();
    _settlingFallbackTimer = null;
    _overlayModel.reset();
  }

  void _beginSettling() {
    _settling = true;
    // Fallback so a missed decode notification can never leave a stale
    // overlay stuck on screen.
    _settlingFallbackTimer?.cancel();
    _settlingFallbackTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _settling) {
        _resetOverlay();
      }
    });
    // Check after the parent rebuild delivers the post-commit session state;
    // checking synchronously would consult the pre-commit surface and clear
    // the overlay immediately, reintroducing the flash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onTileImagesChanged();
    });
  }

  void _onTileImagesChanged() {
    if (!_settling || !mounted) {
      return;
    }
    final tiles = widget.sessionState.canvasState.currentSurface.tiles.values;
    if (BitmapTileImageCache.instance.allDecoded(tiles)) {
      _resetOverlay();
    }
  }

  /// Folds stamped dabs into the model's flattened image once enough
  /// accumulate, so neither repaints nor flattens ever touch the whole
  /// stroke again.
  void _maybeFlattenOverlay() {
    if (_overlayModel.dabs.length - _overlayModel.paintFrom <
        _flattenBatchSize) {
      return;
    }
    final canvasSize =
        widget.sessionState.canvasState.currentSurface.canvasSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final previous = _overlayModel.flattened;
    if (previous != null) {
      canvas.drawImage(
        previous,
        Offset.zero,
        Paint()
          ..isAntiAlias = false
          ..filterQuality = FilterQuality.none,
      );
    }
    ActiveStrokeOverlayPainter.paintDabStamps(
      canvas,
      _overlayModel.dabs,
      BrushTipMaskCache.instance,
      from: _overlayModel.paintFrom,
    );
    final picture = recorder.endRecording();
    final flattened = picture.toImageSync(canvasSize.width, canvasSize.height);
    picture.dispose();
    previous?.dispose();
    _overlayModel.flattened = flattened;
    _overlayModel.paintFrom = _overlayModel.dabs.length;
  }
}
