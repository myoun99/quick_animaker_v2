import 'dart:async';

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
import '../../services/brush_live_stroke_rasterizer.dart';
import '../../services/brush_stroke_commit_data.dart';
import '../../services/canvas_segment_clipper.dart';
import 'active_stroke_overlay_painter.dart';
import 'bitmap_tile_image_cache.dart';
import 'brush_edit_canvas_input_settings.dart';
import 'brush_edit_canvas_view.dart';

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
  final ValueChanged<BrushStrokeCommitData> onSourceStrokeCommitted;
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
  int? _activeDrawingPointer;
  int? _activePanPointer;
  Offset? _panStartLocalPosition;
  CanvasViewport? _panStartViewport;
  var _nextSequence = 0;
  final List<BrushDab> _collectedDabs = <BrushDab>[];
  var _breakCurrentVisibleSegment = false;
  CanvasPoint? _previousRawCanvasPosition;
  BrushEditCanvasInputSettings? _activeStrokeInputSettings;

  /// Live overlay state. Pointer moves blend new dabs into [_liveRasterizer]
  /// (the exact commit-rasterizer math), convert the touched region into a
  /// segment sprite, and notify the overlay painter directly through this
  /// model — no widget rebuild per move, and the pixels on screen are the
  /// pixels the commit will keep.
  final ActiveStrokeOverlayModel _overlayModel = ActiveStrokeOverlayModel();

  BrushLiveStrokeRasterizer? _liveRasterizer;

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
              // The viewport transform is applied inside the painter (not by
              // a Transform widget) so the canvas rasterizes at final device
              // resolution in one picture — pixel-stable at fractional zoom.
              child: BrushEditCanvasView(
                sessionState: widget.sessionState,
                viewport: widget.viewport,
                showTransparentBackground: widget.showTransparentBackground,
                overlayModel: _overlayModel,
                staleScope: (widget.layerId, widget.frameId),
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
    _prepareLiveRasterizer();
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
    _appendOverlayDabs(initialDabs);
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

    // No setState: pointer moves rasterize the new dabs and repaint the
    // overlay layer directly, skipping the widget rebuild entirely (this
    // runs at pointer-sample frequency).
    if (segmentStartDabs.isNotEmpty) {
      _collectedDabs.addAll(segmentStartDabs);
    }
    if (segmentEndDabs.isNotEmpty) {
      _collectedDabs.addAll(segmentEndDabs);
    }
    _appendOverlayDabs([...segmentStartDabs, ...segmentEndDabs]);
    _nextSequence += addedDabCount;
    _breakCurrentVisibleSegment = false;
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
      final rasterizer = _liveRasterizer;
      widget.onSourceStrokeCommitted(
        BrushStrokeCommitData(
          sourceDabs: _collectedDabs,
          strokePixels: rasterizer?.strokeBounds == null
              ? null
              : rasterizer!.pixels,
          strokeBounds: rasterizer?.strokeBounds,
        ),
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

  /// Creates or recycles the live stroke rasterizer for the current canvas.
  void _prepareLiveRasterizer() {
    final canvasSize =
        widget.sessionState.canvasState.currentSurface.canvasSize;
    final existing = _liveRasterizer;
    if (existing == null || existing.canvasSize != canvasSize) {
      _liveRasterizer = BrushLiveStrokeRasterizer(canvasSize: canvasSize);
    } else {
      existing.clear();
    }
  }

  /// Rasterizes [newDabs] into the live buffer (exact commit math), folds
  /// the touched region into the overlay image off-screen, and repaints.
  ///
  /// The region replacement happens in image space (integer pixel grid);
  /// the on-screen painter only draws the finished image with source-over,
  /// which stays artifact-free at fractional zoom levels.
  void _appendOverlayDabs(List<BrushDab> newDabs) {
    if (newDabs.isEmpty) {
      return;
    }
    final rasterizer = _liveRasterizer;
    if (rasterizer == null) {
      return;
    }
    final from = _overlayModel.dabs.length;
    _overlayModel.dabs.addAll(newDabs);
    final region = rasterizer.blendFrom(_overlayModel.dabs, from: from);
    if (region != null) {
      final sprite = strokeRegionSprite(
        pixels: rasterizer.pixels,
        canvasWidth: rasterizer.canvasSize.width,
        region: region,
      );
      final previous = _overlayModel.overlayImage;
      _overlayModel.overlayImage = composeOverlayImage(
        previous: previous,
        regionSprite: sprite,
        regionOffset: Offset(region.left.toDouble(), region.top.toDouble()),
        canvasWidth: rasterizer.canvasSize.width,
        canvasHeight: rasterizer.canvasSize.height,
      );
      sprite.dispose();
      previous?.dispose();
    }
    _overlayModel.markChanged();
  }
}
