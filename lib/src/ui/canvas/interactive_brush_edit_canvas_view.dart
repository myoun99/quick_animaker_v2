import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/brush_edit_session_state.dart';
import '../../models/canvas_point.dart';
import '../../models/canvas_viewport.dart';
import '../../models/viewport_point.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../services/brush_dab_interpolator.dart';
import '../../services/brush_live_stroke_rasterizer.dart';
import '../../services/brush_stroke_dynamics.dart';
import '../../services/brush_pressure_dynamics.dart';
import '../../services/brush_stroke_commit_data.dart';
import '../../services/canvas_segment_clipper.dart';
import 'active_stroke_overlay.dart';
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

  /// Zoom/pan applied to the canvas display and input mapping. Viewport
  /// GESTURES (middle-drag pan, wheel zoom) live on the panel's
  /// [CanvasViewportGestureLayer], not here — this view only draws.
  final CanvasViewport viewport;

  @override
  State<InteractiveBrushEditCanvasView> createState() =>
      _InteractiveBrushEditCanvasViewState();
}

class _InteractiveBrushEditCanvasViewState
    extends State<InteractiveBrushEditCanvasView> {
  int? _activeDrawingPointer;
  var _nextSequence = 0;
  final List<BrushDab> _collectedDabs = <BrushDab>[];
  var _breakCurrentVisibleSegment = false;
  CanvasPoint? _previousRawCanvasPosition;
  BrushEditCanvasInputSettings? _activeStrokeInputSettings;

  /// Normalized pressure (0..1) of the latest pointer sample. Devices without
  /// pressure report a zero range and are treated as full pressure, so a
  /// mouse draws exactly as before.
  double _currentPressure = 1.0;

  /// Placement dynamics (scatter/jitter/direction rotation) for the active
  /// stroke; created at pointer-down from the stroke's settings snapshot.
  BrushStrokeDynamics? _strokeDynamics;

  /// Per-stroke randomness for the dual-mask phase; each dab samples the
  /// dual texture at its own random offset (stored on the dab, so replay
  /// is deterministic).
  final math.Random _dualPhaseRandom = math.Random();

  /// Latest known stroke direction (visual CCW degrees); kept across
  /// stationary events so direction-following tips do not snap back.
  double? _lastDirectionDegrees;

  /// Last dab of the UNTRANSFORMED interpolation chain. Interpolation must
  /// anchor on the base chain — anchoring on scattered/jittered dabs would
  /// wander the spacing.
  BrushDab? _previousBaseDab;

  /// Live overlay state. Pointer moves blend new dabs into [_liveRasterizer]
  /// (the exact commit-rasterizer math) and re-decode the touched overlay
  /// tiles; decode completions repaint the canvas painter directly through
  /// this model — no widget rebuild per move, and the pixels on screen are
  /// the pixels the commit will keep.
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
    if (_activeDrawingPointer != null || !_isPrimaryButton(event.buttons)) {
      return;
    }

    final canvasPosition = _canvasPositionFromLocal(event.localPosition);
    final startsInsideSurface = _isInsideSurface(canvasPosition);

    _activeDrawingPointer = event.pointer;
    _activeStrokeInputSettings = widget.inputSettings;
    _currentPressure = _normalizedPressure(event);
    widget.onActiveStrokeChanged?.call(true);
    _nextSequence = 0;
    _breakCurrentVisibleSegment = !startsInsideSurface;
    _previousRawCanvasPosition = canvasPosition;
    _strokeDynamics = BrushStrokeDynamics(settings: widget.inputSettings);
    _lastDirectionDegrees = null;
    _previousBaseDab = null;
    _resetOverlay();
    _collectedDabs.clear();
    _prepareLiveRasterizer();
    if (!startsInsideSurface) {
      return;
    }
    final initialDabs = _withPressureDynamics(
      widget.dabInterpolator.interpolate(
        previous: null,
        nextRaw: _dabFromPosition(canvasPosition, sequence: _nextSequence),
        firstSequence: _nextSequence,
        spacingRatio: _activeStrokeSpacing,
      ),
    );
    if (initialDabs.isNotEmpty) {
      _previousBaseDab = initialDabs.last;
    }
    final emitted = _strokeDynamics!.apply(
      initialDabs,
      firstSequence: _nextSequence,
      directionDegrees: null,
    );
    _collectedDabs.addAll(emitted);
    _appendOverlayDabs(emitted);
    _nextSequence += emitted.length;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activeDrawingPointer) {
      return;
    }

    _currentPressure = _normalizedPressure(event);
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
            _previousBaseDab == null
        ? null
        : _previousBaseDab;
    final segmentStartDabs =
        clippedSegment.startsNewVisibleSegment ||
            _breakCurrentVisibleSegment ||
            _previousBaseDab == null
        ? _withPressureDynamics(
            widget.dabInterpolator.interpolate(
              previous: null,
              nextRaw: _dabFromPosition(
                clippedSegment.start,
                sequence: _nextSequence,
              ),
              firstSequence: _nextSequence,
              spacingRatio: _activeStrokeSpacing,
            ),
          )
        : const <BrushDab>[];
    final firstEndSequence = _nextSequence + segmentStartDabs.length;
    final endPrevious = segmentStartDabs.isNotEmpty
        ? segmentStartDabs.last
        : previousDab;
    final segmentEndDabs = _withPressureDynamics(
      widget.dabInterpolator.interpolate(
        previous: endPrevious,
        nextRaw: _dabFromPosition(
          clippedSegment.end,
          sequence: firstEndSequence,
        ),
        firstSequence: firstEndSequence,
        spacingRatio: _activeStrokeSpacing,
      ),
    );
    final baseDabs = <BrushDab>[...segmentStartDabs, ...segmentEndDabs];
    if (baseDabs.isEmpty) {
      return;
    }
    _previousBaseDab = baseDabs.last;

    _lastDirectionDegrees =
        strokeDirectionDegrees(from: previousRaw, to: canvasPosition) ??
        _lastDirectionDegrees;
    final emitted =
        _strokeDynamics?.apply(
          baseDabs,
          firstSequence: _nextSequence,
          directionDegrees: _lastDirectionDegrees,
        ) ??
        baseDabs;

    // No setState: pointer moves rasterize the new dabs and repaint the
    // overlay layer directly, skipping the widget rebuild entirely (this
    // runs at pointer-sample frequency).
    _collectedDabs.addAll(emitted);
    _appendOverlayDabs(emitted);
    _nextSequence += emitted.length;
    _breakCurrentVisibleSegment = false;
  }

  void _handlePointerUp(PointerUpEvent event) {
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
    if (event.pointer != _activeDrawingPointer) {
      return;
    }

    _endStrokeInput();
    _resetOverlay();
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

  /// Builds a dab carrying the base tool size/opacity and the current input
  /// pressure. Pressure scaling is applied after interpolation (see
  /// [_withPressureDynamics]) so each inserted dab scales by its own
  /// interpolated pressure rather than the segment endpoint's.
  BrushDab _dabFromPosition(
    CanvasPoint localPosition, {
    required int sequence,
  }) {
    final settings = _activeStrokeInputSettings ?? widget.inputSettings;
    final dualMask = settings.dualMask;
    return BrushDab(
      center: localPosition,
      color: settings.color,
      size: settings.size,
      opacity: settings.opacity,
      flow: settings.flow,
      hardness: settings.hardness,
      tipShape: settings.tipShape,
      pressure: _currentPressure,
      sequence: sequence,
      roundness: settings.roundness,
      angleDegrees: settings.angleDegrees,
      tipMask: settings.tipMask,
      dualMask: dualMask,
      dualMaskScale: settings.dualMaskScale,
      dualOffsetU: dualMask == null ? 0.0 : _dualPhaseRandom.nextDouble(),
      dualOffsetV: dualMask == null ? 0.0 : _dualPhaseRandom.nextDouble(),
      textureMask: settings.textureMask,
      textureScale: settings.textureScale,
      textureDensity: settings.textureDensity,
    );
  }

  /// Scales freshly interpolated dabs by their pressure per the active
  /// stroke's pressure toggles. Returns the input unchanged when neither
  /// toggle is on, so the common no-pressure path stays allocation-free.
  List<BrushDab> _withPressureDynamics(List<BrushDab> dabs) {
    final settings = _activeStrokeInputSettings ?? widget.inputSettings;
    if (!settings.pressureSize && !settings.pressureOpacity) {
      return dabs;
    }
    return <BrushDab>[
      for (final dab in dabs)
        applyBrushPressureDynamics(
          dab,
          pressureSize: settings.pressureSize,
          pressureOpacity: settings.pressureOpacity,
          minimumSizeRatio: settings.minimumSizeRatio,
        ),
    ];
  }

  /// Normalizes a pointer's pressure into 0..1.
  ///
  /// Only stylus devices report meaningful pressure. A mouse claims a 0..1
  /// pressure range on some platforms while always reporting 0.0 — trusting
  /// it made pressure-sized strokes invisible — and touch pressure is
  /// unreliable across devices, so both paint at full pressure.
  double _normalizedPressure(PointerEvent event) {
    if (event.kind != PointerDeviceKind.stylus &&
        event.kind != PointerDeviceKind.invertedStylus) {
      return 1.0;
    }
    final range = event.pressureMax - event.pressureMin;
    if (!range.isFinite || range <= 0.0) {
      return 1.0;
    }
    return ((event.pressure - event.pressureMin) / range).clamp(0.0, 1.0);
  }

  double get _activeStrokeSpacing =>
      (_activeStrokeInputSettings ?? widget.inputSettings).spacing;

  bool _isPrimaryButton(int buttons) {
    return buttons == kPrimaryMouseButton;
  }

  void _endStrokeInput() {
    widget.onActiveStrokeChanged?.call(false);
    _activeDrawingPointer = null;
    _nextSequence = 0;
    _breakCurrentVisibleSegment = false;
    _previousRawCanvasPosition = null;
    _activeStrokeInputSettings = null;
    _currentPressure = 1.0;
    _strokeDynamics = null;
    _lastDirectionDegrees = null;
    _previousBaseDab = null;
    _collectedDabs.clear();
  }

  /// Clears the visible overlay (live or settling) and its tile images.
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

  /// Rasterizes [newDabs] into the live buffer (exact commit math) and
  /// re-decodes the touched overlay tiles.
  ///
  /// The overlay model snapshots and decodes each touched tile through the
  /// same premultiply + `decodeImageFromPixels` pipeline as the committed
  /// tiles, so the on-screen stroke rasterizes exactly like it will after
  /// commit; decode completions repaint the canvas painter directly.
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
      _overlayModel.updateRegion(
        pixels: rasterizer.pixels,
        canvasWidth: rasterizer.canvasSize.width,
        canvasHeight: rasterizer.canvasSize.height,
        region: region,
      );
    }
  }
}
