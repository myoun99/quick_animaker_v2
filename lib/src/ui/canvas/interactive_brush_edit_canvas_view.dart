import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../models/bitmap_surface.dart';
import '../../models/bitmap_tile.dart';
import '../../models/brush_dab.dart';
import '../../models/brush_edit_session_state.dart';
import '../../models/canvas_point.dart';
import '../../models/dirty_region.dart';
import '../../models/canvas_viewport.dart';
import '../../models/tile_coord.dart';
import '../../models/viewport_point.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../services/brush_dab_interpolator.dart';
import '../../services/brush_live_stroke_rasterizer.dart';
import '../../services/brush_stroke_dynamics.dart';
import '../../services/brush_pressure_dynamics.dart';
import '../../services/brush_stroke_commit_data.dart';
import '../../services/canvas_segment_clipper.dart';
import '../../services/stroke_stabilizer.dart';
import 'active_stroke_overlay.dart';
import 'bitmap_tile_image_cache.dart';
import 'brush_edit_canvas_input_settings.dart';
import 'brush_edit_canvas_view.dart';

/// The committed-surface tiles inside [bounds] (every stored tile when the
/// bounds are unknown): the set whose decodes gate the settling overlay
/// handoff, so a just-committed stroke never trades its overlay for stale
/// pre-stroke tile images.
@visibleForTesting
List<BitmapTile> settlingTilesForBounds({
  required BitmapSurface surface,
  required DirtyRegion? bounds,
}) {
  if (bounds == null) {
    return surface.tiles.values.toList();
  }
  final tileSize = surface.tileSize;
  final minX = bounds.left ~/ tileSize;
  final maxX = (bounds.rightExclusive - 1) ~/ tileSize;
  final minY = bounds.top ~/ tileSize;
  final maxY = (bounds.bottomExclusive - 1) ~/ tileSize;
  return [
    for (final tile in surface.tiles.values)
      if (tile.coord.x >= minX &&
          tile.coord.x <= maxX &&
          tile.coord.y >= minY &&
          tile.coord.y <= maxY)
        tile,
  ];
}

/// The PRE-stroke tile (null = the coordinate was empty) for every
/// committed-grid coordinate that [bounds] touches; captured at pen-up
/// while the session surface is still pre-commit, and pinned on the
/// overlay model so settling frames stay pixel-identical to the live
/// stroke (see [ActiveStrokeOverlayModel.settleHoldTiles]).
@visibleForTesting
Map<TileCoord, BitmapTile?> preStrokeHoldTiles({
  required BitmapSurface surface,
  required DirtyRegion? bounds,
}) {
  if (bounds == null) {
    return {for (final tile in surface.tiles.values) tile.coord: tile};
  }
  final tileSize = surface.tileSize;
  final minX = bounds.left ~/ tileSize;
  final maxX = (bounds.rightExclusive - 1) ~/ tileSize;
  final minY = bounds.top ~/ tileSize;
  final maxY = (bounds.bottomExclusive - 1) ~/ tileSize;
  final tiles = surface.tiles;
  return {
    for (var y = minY; y <= maxY; y += 1)
      for (var x = minX; x <= maxX; x += 1)
        TileCoord(x: x, y: y): tiles[TileCoord(x: x, y: y)],
  };
}

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

  /// Live touch contacts. A second finger switches the interaction to
  /// viewport navigation (handled by the panel's gesture layer): the
  /// in-progress stroke is cancelled without committing, and no new stroke
  /// starts until every finger lifts — a quick pinch never leaves marks.
  final Set<int> _activeTouchPointers = <int>{};
  bool _multiTouchNavigation = false;
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

  /// Pull-string stabilization for the active stroke (P7): created at
  /// pointer-down when the strength is non-zero (rope = screen px / zoom,
  /// frozen per stroke); pen positions run through it BEFORE clipping and
  /// interpolation, so every downstream route sees the smoothed chain.
  StrokeStabilizer? _stabilizer;

  /// The last RAW pen position (pre-stabilization) — pen-up catches the
  /// brush up to it with a straight segment through the normal pipeline.
  CanvasPoint? _lastPenPosition;

  /// Live overlay state. Pointer moves blend new dabs into [_liveRasterizer]
  /// (the exact commit-rasterizer math) and re-decode the touched overlay
  /// tiles; decode completions repaint the canvas painter directly through
  /// this model — no widget rebuild per move, and the pixels on screen are
  /// the pixels the commit will keep.
  final ActiveStrokeOverlayModel _overlayModel = ActiveStrokeOverlayModel();

  BrushLiveStrokeRasterizer? _liveRasterizer;

  /// Dabs collected since the last rasterized batch. Pointer samples arrive
  /// far above the display rate (1000Hz mice, 240Hz pens); rasterizing per
  /// EVENT multiplied the blend work for zero visible benefit, so moves only
  /// queue dabs and one frame callback blends the batch. Dab generation,
  /// order and blend math are unchanged — the batch is byte-identical to
  /// per-event blending, and pen-up flushes synchronously before commit.
  final List<BrushDab> _pendingOverlayDabs = <BrushDab>[];
  bool _overlayFlushScheduled = false;

  // After pointer-up the overlay stays visible ("settling") until the
  // committed tiles finish decoding, so the stroke never flashes away while
  // the display switches to the materialized bitmap.
  bool _settling = false;
  Timer? _settlingFallbackTimer;

  /// Canvas region the settling stroke touched: only ITS tiles gate the
  /// overlay handoff (checking the whole surface stalled the drop on
  /// unrelated tiles, and the old flat 300ms give-up then revealed stale
  /// pre-stroke tiles — the "part of the stroke blinks" bug).
  DirtyRegion? _settlingBounds;

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
    if (event.kind == PointerDeviceKind.touch) {
      _activeTouchPointers.add(event.pointer);
      if (_activeTouchPointers.length >= 2) {
        _multiTouchNavigation = true;
        // Discard only a TOUCH stroke — the first finger turned out to be
        // the start of a pinch, not a stroke. A stylus/mouse stroke keeps
        // drawing: extra touch contacts alongside it are palm rests, and
        // the gesture layer holds navigation while any stroke is active.
        if (_activeDrawingPointer != null &&
            _activeTouchPointers.contains(_activeDrawingPointer)) {
          _endStrokeInput();
          _resetOverlay();
        }
        return;
      }
    }

    if (_multiTouchNavigation ||
        _activeDrawingPointer != null ||
        !_isPrimaryButton(event.buttons)) {
      return;
    }

    final canvasPosition = _canvasPositionFromLocal(event.localPosition);
    final startsInsideSurface = _isInsideSurface(canvasPosition);

    _activeDrawingPointer = event.pointer;
    _activeStrokeInputSettings = widget.inputSettings;
    // The overlay must display in the stroke's blend mode (paint vs erase)
    // from the first dab through settling.
    _overlayModel.erase = widget.inputSettings.erase;
    _currentPressure = _normalizedPressure(event);
    widget.onActiveStrokeChanged?.call(true);
    _nextSequence = 0;
    _breakCurrentVisibleSegment = !startsInsideSurface;
    _previousRawCanvasPosition = canvasPosition;
    _lastPenPosition = canvasPosition;
    final stabilizerStrength = widget.inputSettings.stabilizerStrength;
    _stabilizer = stabilizerStrength > 0
        ? StrokeStabilizer(
            ropeLength: stabilizerStrength / widget.viewport.zoom,
            start: canvasPosition,
          )
        : null;
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
    _queueOverlayDabs(emitted);
    _nextSequence += emitted.length;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activeDrawingPointer) {
      return;
    }

    _currentPressure = _normalizedPressure(event);
    final penPosition = _canvasPositionFromLocal(event.localPosition);
    _lastPenPosition = penPosition;
    // The stabilizer smooths BEFORE clipping/interpolation, so every
    // downstream consumer (overlay, commit, replay) sees one chain — the
    // three-route parity holds by construction (P7).
    _advanceStrokeTo(_stabilizer?.follow(penPosition) ?? penPosition);
  }

  void _advanceStrokeTo(CanvasPoint canvasPosition) {
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

    // No setState: pointer moves only QUEUE the new dabs (this runs at
    // pointer-sample frequency); the per-frame flush rasterizes the batch
    // and repaints the overlay layer directly, skipping widget rebuilds.
    _collectedDabs.addAll(emitted);
    _queueOverlayDabs(emitted);
    _nextSequence += emitted.length;
    _breakCurrentVisibleSegment = false;
  }

  void _queueOverlayDabs(List<BrushDab> newDabs) {
    if (newDabs.isEmpty) {
      return;
    }
    _pendingOverlayDabs.addAll(newDabs);
    if (_overlayFlushScheduled) {
      return;
    }
    _overlayFlushScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _overlayFlushScheduled = false;
      if (mounted) {
        _flushPendingOverlayDabs();
      } else {
        _pendingOverlayDabs.clear();
      }
    });
    // Pointer samples can arrive while no frame is scheduled (nothing else
    // animating); make sure the flush frame actually happens.
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _flushPendingOverlayDabs() {
    if (_pendingOverlayDabs.isEmpty) {
      return;
    }
    final batch = List<BrushDab>.of(_pendingOverlayDabs);
    _pendingOverlayDabs.clear();
    _appendOverlayDabs(batch);
  }

  void _handlePointerUp(PointerUpEvent event) {
    _forgetTouchPointer(event.pointer);
    if (event.pointer != _activeDrawingPointer) {
      return;
    }

    // Stabilizer catch-up (P7): the brush trails the pen by up to a rope
    // length — pen-up closes the gap with one straight segment through
    // the normal pipeline, so line ends land where the pen lifted.
    final lastPen = _lastPenPosition;
    if (_stabilizer != null && lastPen != null) {
      _advanceStrokeTo(lastPen);
    }

    final hadDabs = _collectedDabs.isNotEmpty;
    if (hadDabs) {
      // The commit reads the rasterizer's pixels/bounds — blend any dabs
      // still waiting on the per-frame flush first.
      _flushPendingOverlayDabs();
      final rasterizer = _liveRasterizer;
      // The settling check below watches exactly the tiles this stroke
      // touched; unrelated tiles must not gate the overlay handoff.
      _settlingBounds = rasterizer?.strokeBounds;
      // Pin the PRE-stroke tiles (the surface is still pre-commit here) so
      // the painter never mixes freshly decoded post-commit tiles with the
      // still-visible overlay — that mix flashed the stroke at double
      // density in tile-shaped patches during settling.
      _overlayModel.holdPreStrokeTiles(
        preStrokeHoldTiles(
          surface: widget.sessionState.canvasState.currentSurface,
          bounds: _settlingBounds,
        ),
      );
      widget.onSourceStrokeCommitted(
        BrushStrokeCommitData(
          sourceDabs: _collectedDabs,
          // Bounds-local row-major buffer (stride = bounds width): its
          // allocation scales with the stroke, never the canvas.
          strokePixels: rasterizer?.strokePixelsWithinBounds(),
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
    _forgetTouchPointer(event.pointer);
    if (event.pointer != _activeDrawingPointer) {
      return;
    }

    _endStrokeInput();
    _resetOverlay();
  }

  void _forgetTouchPointer(int pointer) {
    _activeTouchPointers.remove(pointer);
    if (_activeTouchPointers.isEmpty) {
      _multiTouchNavigation = false;
    }
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
      erase: settings.erase,
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
    _stabilizer = null;
    _lastPenPosition = null;
    _collectedDabs.clear();
    _pendingOverlayDabs.clear();
  }

  /// Clears the visible overlay (live or settling) and its tile images.
  void _resetOverlay() {
    _settling = false;
    _settlingBounds = null;
    _settlingFallbackTimer?.cancel();
    _settlingFallbackTimer = null;
    _overlayModel.reset();
  }

  /// How long the settling safety cap keeps waiting for tile decodes
  /// before force-dropping the overlay. Purely a stuck-state escape hatch:
  /// dropping EARLY is what used to blink parts of big strokes back to
  /// their pre-stroke tiles (the old 300ms flat timeout fired before slow
  /// decodes finished), so the deadline is generous and the periodic
  /// re-check below re-requests decodes instead of giving up.
  static const Duration _settlingDeadline = Duration(seconds: 2);
  static const Duration _settlingRecheckInterval = Duration(milliseconds: 50);

  void _beginSettling() {
    _settling = true;
    _settlingFallbackTimer?.cancel();
    var waited = Duration.zero;
    _settlingFallbackTimer = Timer.periodic(_settlingRecheckInterval, (timer) {
      if (!mounted || !_settling) {
        timer.cancel();
        return;
      }
      waited += _settlingRecheckInterval;
      if (waited >= _settlingDeadline) {
        timer.cancel();
        _resetOverlay();
        return;
      }
      // Belt and braces against a missed decode notification: re-request
      // the stroke tiles' decodes and re-run the handoff check.
      _requestSettlingDecodes();
      _onTileImagesChanged();
    });
    // Check after the parent rebuild delivers the post-commit session state;
    // checking synchronously would consult the pre-commit surface and clear
    // the overlay immediately, reintroducing the flash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestSettlingDecodes();
      _onTileImagesChanged();
    });
  }

  /// The committed-surface tiles the settling stroke touched (all tiles
  /// when the bounds are unknown).
  List<BitmapTile> _settlingTiles() {
    return settlingTilesForBounds(
      surface: widget.sessionState.canvasState.currentSurface,
      bounds: _settlingBounds,
    );
  }

  void _requestSettlingDecodes() {
    if (!_settling || !mounted) {
      return;
    }
    for (final tile in _settlingTiles()) {
      BitmapTileImageCache.instance.ensureDecoded(
        tile,
        staleScope: (widget.layerId, widget.frameId),
      );
    }
  }

  void _onTileImagesChanged() {
    if (!_settling || !mounted) {
      return;
    }
    if (BitmapTileImageCache.instance.allDecoded(_settlingTiles())) {
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
      _overlayModel.updateRegion(source: rasterizer, region: region);
    }
  }
}
