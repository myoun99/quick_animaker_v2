import '../models/attached_layer_resolve.dart';
import '../models/bitmap_surface.dart';
import '../models/canvas_point.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/frame.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/layer_kind.dart';
import '../models/timeline_coverage.dart';
import '../models/transform_track.dart';

/// One paintable layer of a composited cut frame, bottom → top order.
class CutFrameCompositeLayer {
  const CutFrameCompositeLayer({
    required this.surface,
    required this.opacity,
    this.pose,
    this.anchorPoint,
  });

  final BitmapSurface surface;

  /// The layer's EFFECTIVE opacity: the static layer opacity multiplied by
  /// the transform track's animated Opacity sample (compose routes paint
  /// with exactly this value).
  final double opacity;

  /// The layer's transform at this frame; null = identity (no transform
  /// work — the overwhelmingly common case skips the canvas save/restore).
  final TransformPose? pose;

  /// The pose's anchor point; null = canvas center (see
  /// applyLayerPoseTransform).
  final CanvasPoint? anchorPoint;
}

/// A layer's identity pose: content centered, unscaled, unrotated — the
/// same canvas-centered shape the camera defaults to, so an empty track
/// composites exactly as before.
TransformPose layerIdentityPose(CanvasSize canvasSize) => TransformPose(
  center: CanvasPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
);

/// The layer's resolved GEOMETRIC pose at [frameIndex]; null while the
/// geometric tracks (anchor/position/scale/rotation) are empty — an
/// animated Opacity alone never forces the transform path. Shared by the
/// composite plan, the composite cache signature and the editing canvas's
/// layer stack so every route agrees.
TransformPose? resolveLayerPoseAt({
  required Layer layer,
  required CanvasSize canvasSize,
  required int frameIndex,
}) {
  final track = layer.transformTrack;
  if (track.anchorPoint.isEmpty &&
      track.position.isEmpty &&
      track.scale.isEmpty &&
      track.rotation.isEmpty) {
    return null;
  }
  return track.resolveAt(
    frameIndex: frameIndex,
    orElse: () => layerIdentityPose(canvasSize),
  );
}

/// The layer's resolved anchor point at [frameIndex]; null = canvas center
/// (the anchor-point lane's empty-track default).
CanvasPoint? resolveLayerAnchorPointAt({
  required Layer layer,
  required int frameIndex,
}) {
  return resolveAnchorTrackAt(layer.transformTrack.anchorPoint, frameIndex);
}

/// The layer's effective opacity at [frameIndex]: static layer opacity ×
/// the animated Opacity sample (1 while unkeyed), clamped to 0..1.
double resolveLayerEffectiveOpacityAt({
  required Layer layer,
  required int frameIndex,
}) {
  return (layer.opacity *
          resolveOpacityTrackAt(layer.transformTrack.opacity, frameIndex))
      .clamp(0.0, 1.0)
      .toDouble();
}

/// Resolves the drawable surface for a layer's frame (e.g. by replaying the
/// brush store's paint commands); `null` when the frame has no artwork.
typedef LayerFrameSurfaceResolver =
    BitmapSurface? Function(Layer layer, Frame frame);

/// One resolved contributor to the cut's picture at a frame — the SHARED
/// visit both the composite plan and the composite cache signature consume,
/// so every route (playback, export, thumbnails, editing stack) agrees on
/// skip rules, exposure resolution AND the attach-layer expansion by
/// construction.
class CutFrameCompositeEntry {
  const CutFrameCompositeEntry({
    required this.layer,
    required this.frame,
    required this.opacity,
    this.pose,
    this.anchorPoint,
  });

  final Layer layer;
  final Frame frame;
  final double opacity;
  final TransformPose? pose;
  final CanvasPoint? anchorPoint;
}

/// The visible contributors at [frameIndex], bottom → top.
///
/// Layers are visited in list order (first = bottom, later layers draw on
/// top, matching "add layer above"). The camera layer, hidden layers and
/// fully transparent layers are skipped. Exposure resolution matches the
/// timeline: the drawing block covering [frameIndex] shows; uncovered
/// cells contribute nothing.
///
/// ATTACH LAYERS (W5) ride their base: the cel resolves through the base's
/// exposure + the cell link, the POSE and the animated-opacity sample come
/// from the BASE's transform track (fx shared — the base's fx switch
/// governs both), while the eye, static opacity and cels stay the attach
/// layer's own. Hiding the base hides its attach layers too (they are part
/// of the base's group); dangling links contribute nothing. The layer list
/// keeps attach layers adjacent to their base, so plain list order already
/// yields [below…, base, above…].
///
/// Layers in [fxBypassedLayerIds] compose with their FX ignored — identity
/// pose and no animated opacity (the layer-label fx switch, session view
/// state).
///
/// A non-null [soloVisibleLayerId] REPLACES the eye predicate (the legend's
/// visibility-solo mode, session view state): only the soloed layer — plus
/// its attach layers, which are part of its group — contributes, eyes
/// ignored either way. Static opacity still gates.
List<CutFrameCompositeEntry> resolveCutFrameCompositeEntries({
  required Cut cut,
  required int frameIndex,
  Set<LayerId> fxBypassedLayerIds = const {},
  LayerId? soloVisibleLayerId,
}) {
  final entries = <CutFrameCompositeEntry>[];
  for (final layer in cut.layers) {
    if (layer.kind == LayerKind.camera) {
      continue;
    }
    final base = isAttachedLayer(layer)
        ? attachedBaseOf(layer, cut.layers)
        : null;
    if (isAttachedLayer(layer) && base == null) {
      // Dangling attach link (base gone): the row contributes nothing.
      continue;
    }
    if (soloVisibleLayerId != null) {
      // Solo mode: the soloed layer's GROUP passes (itself + attach rows
      // riding it), everything else is hidden regardless of eyes.
      if (layer.id != soloVisibleLayerId &&
          (base ?? layer).id != soloVisibleLayerId) {
        continue;
      }
      if (layer.opacity <= 0) {
        continue;
      }
    } else {
      // The base's eye cascades over its attach layers; each row's own eye
      // and static opacity gate it individually.
      if (base != null && !base.isVisible) {
        continue;
      }
      if (!layer.isVisible || layer.opacity <= 0) {
        continue;
      }
    }
    final fxCarrier = base ?? layer;
    final fxEnabled = !fxBypassedLayerIds.contains(fxCarrier.id);
    final opacity = fxEnabled
        ? (layer.opacity *
                  resolveOpacityTrackAt(
                    fxCarrier.transformTrack.opacity,
                    frameIndex,
                  ))
              .clamp(0.0, 1.0)
              .toDouble()
        : layer.opacity.clamp(0.0, 1.0).toDouble();
    if (opacity <= 0) {
      continue;
    }

    final frame = base == null
        ? resolveExposedFrameAt(layer, frameIndex)
        : resolveAttachedFrameAt(
            attached: layer,
            base: base,
            frameIndex: frameIndex,
          );
    if (frame == null) {
      continue;
    }

    entries.add(
      CutFrameCompositeEntry(
        layer: layer,
        frame: frame,
        opacity: opacity,
        pose: fxEnabled
            ? resolveLayerPoseAt(
                layer: fxCarrier,
                canvasSize: cut.canvasSize,
                frameIndex: frameIndex,
              )
            : null,
        anchorPoint: fxEnabled
            ? resolveLayerAnchorPointAt(
                layer: fxCarrier,
                frameIndex: frameIndex,
              )
            : null,
      ),
    );
  }
  return entries;
}

/// Plans which surfaces make up the cut's picture at [frameIndex] — the
/// shared [resolveCutFrameCompositeEntries] visit with surfaces resolved
/// (entries whose frame has no artwork drop out).
List<CutFrameCompositeLayer> planCutFrameComposite({
  required Cut cut,
  required int frameIndex,
  required LayerFrameSurfaceResolver surfaceResolver,
  Set<LayerId> fxBypassedLayerIds = const {},
  LayerId? soloVisibleLayerId,
}) {
  final plan = <CutFrameCompositeLayer>[];
  for (final entry in resolveCutFrameCompositeEntries(
    cut: cut,
    frameIndex: frameIndex,
    fxBypassedLayerIds: fxBypassedLayerIds,
    soloVisibleLayerId: soloVisibleLayerId,
  )) {
    final surface = surfaceResolver(entry.layer, entry.frame);
    if (surface == null) {
      continue;
    }
    plan.add(
      CutFrameCompositeLayer(
        surface: surface,
        opacity: entry.opacity,
        pose: entry.pose,
        anchorPoint: entry.anchorPoint,
      ),
    );
  }
  return plan;
}

/// The frame exposed at [frameIndex]: the drawing block covering the index
/// (same semantics as TimelineController.resolveFrameForLayer — uncovered
/// cells and marks in empty space show nothing). Shared by the composite
/// plan and the composite cache signature so both always agree on what a
/// frame shows.
Frame? resolveExposedFrameAt(Layer layer, int frameIndex) {
  final frameId = exposedFrameIdAt(layer.timeline, frameIndex);
  if (frameId == null) {
    return null;
  }

  for (final frame in layer.frames) {
    if (frame.id == frameId) {
      return frame;
    }
  }
  return null;
}
