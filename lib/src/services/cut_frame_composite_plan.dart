import '../models/attached_layer_resolve.dart';
import '../models/bitmap_surface.dart';
import '../models/canvas_point.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/frame.dart';
import '../models/layer.dart';
import '../models/layer_blend_mode.dart';
import '../models/layer_folder.dart';
import '../models/layer_id.dart';
import '../models/layer_kind.dart';
import '../models/timeline_coverage.dart';
import '../models/transform_track.dart';
import '../ui/canvas/layer_pose_paint.dart';

/// One paintable layer of a composited cut frame, bottom → top order.
class CutFrameCompositeLayer {
  const CutFrameCompositeLayer({
    required this.surface,
    required this.opacity,
    this.blendMode = LayerBlendMode.normal,
    this.pose,
    this.anchorPoint,
  });

  final BitmapSurface surface;

  /// The layer's composite blend against everything below (R26 #30).
  final LayerBlendMode blendMode;

  /// The layer's EFFECTIVE opacity: static layer opacity × animated
  /// Opacity sample × every enclosing folder's effective opacity (L3 —
  /// folded per member; overlapping members inside one translucent
  /// folder double-blend, the exact buffered group is a later slice).
  final double opacity;

  /// The layer's transform at this frame — WITH every enclosing folder's
  /// FX composed outside it (L3, 폴더째 이동); null = identity (no
  /// transform work — the overwhelmingly common case skips the canvas
  /// save/restore).
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
    this.blendMode = LayerBlendMode.normal,
    this.pose,
    this.anchorPoint,
  });

  final Layer layer;
  final Frame frame;
  final double opacity;

  /// The layer's composite blend against everything below (R26 #30).
  final LayerBlendMode blendMode;

  /// The layer's transform at this frame — WITH every enclosing folder's
  /// FX composed outside it (L3); null = identity.
  final TransformPose? pose;
  final CanvasPoint? anchorPoint;
}

/// A folder chain's composite-relevant state at [frameIndex]: whether the
/// subtree shows at all, the folded opacity factor (each folder's static
/// opacity × its animated Opacity sample), and the folder poses to apply
/// outermost-first. Folder FX lanes are per-use ("레인만 각자") — this
/// resolves THIS cut's folder table.
({
  bool visible,
  double opacityFactor,
  LayerBlendMode blendMode,
  List<LayerPoseSample> poses,
})
resolveFolderChainAt({
  required Cut cut,
  required Layer layer,
  required int frameIndex,
}) {
  final chain = cut.folders.ancestryOf(layer.folderId);
  if (chain.isEmpty) {
    return (
      visible: true,
      opacityFactor: 1.0,
      blendMode: LayerBlendMode.normal,
      poses: const [],
    );
  }
  var opacityFactor = 1.0;
  // R27 #29: the nearest folder that actually sets a blend wins for the
  // members below it. v1 limitation, shared with folder OPACITY since
  // L3: the mode rides each member's own composite draw rather than a
  // folder-wide saveLayer, so overlapping members blend individually.
  var chainBlend = LayerBlendMode.normal;
  final poses = <LayerPoseSample>[];
  // ancestryOf is nearest-first; walk reversed so poses apply outermost
  // first (the outer folder moves the inner one too).
  for (final folder in chain.reversed) {
    if (!folder.isVisible) {
      return (
        visible: false,
        opacityFactor: 0.0,
        blendMode: LayerBlendMode.normal,
        poses: const [],
      );
    }
    if (folder.blendMode != LayerBlendMode.normal) {
      chainBlend = folder.blendMode;
    }
    opacityFactor *=
        (folder.opacity *
                resolveOpacityTrackAt(folder.transformTrack.opacity, frameIndex))
            .clamp(0.0, 1.0);
    final track = folder.transformTrack;
    final hasGeometry =
        track.anchorPoint.isNotEmpty ||
        track.position.isNotEmpty ||
        track.scale.isNotEmpty ||
        track.rotation.isNotEmpty;
    if (hasGeometry) {
      poses.add((
        pose: track.resolveAt(
          frameIndex: frameIndex,
          orElse: () => layerIdentityPose(cut.canvasSize),
        ),
        anchorPoint: resolveAnchorTrackAt(track.anchorPoint, frameIndex),
      ));
    }
  }
  return (
    visible: true,
    opacityFactor: opacityFactor,
    blendMode: chainBlend,
    poses: List.unmodifiable(poses),
  );
}

/// [layerSample] with the folder chain's poses composed OUTSIDE it via
/// [composeLayerPoseSamples] — ONE pose per entry, so every consumer
/// (composite cache, camera renders, editing stack, signatures) applies
/// folder FX with zero changes. Null when neither the folders nor the
/// layer carry geometry.
LayerPoseSample? composeFolderAndLayerPose({
  required List<LayerPoseSample> folderPoses,
  required LayerPoseSample? layerSample,
  required CanvasSize canvasSize,
}) {
  if (folderPoses.isEmpty) {
    return layerSample;
  }
  var combined =
      layerSample ??
      (pose: layerIdentityPose(canvasSize), anchorPoint: null as CanvasPoint?);
  // Fold innermost-outward: outer ∘ (… ∘ (inner ∘ layer)).
  for (final folderPose in folderPoses.reversed) {
    combined = composeLayerPoseSamples(folderPose, combined, canvasSize);
  }
  return combined;
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
/// layer's own. VISIBILITY is fully independent (UI-R24 #5): hiding the
/// base hides ONLY the base's own picture — its attach rows keep
/// compositing under their own eyes. Dangling links contribute nothing.
/// The layer list keeps attach layers adjacent to their base, so plain
/// list order already yields [below…, base, above…].
///
/// Layers in [fxBypassedLayerIds] compose with their FX ignored — identity
/// pose and no animated opacity (the layer-label fx switch, session view
/// state).
List<CutFrameCompositeEntry> resolveCutFrameCompositeEntries({
  required Cut cut,
  required int frameIndex,
  Set<LayerId> fxBypassedLayerIds = const {},
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
    // Each row's OWN eye and static opacity gate it — the base's eye
    // never cascades (UI-R24 #5: hiding the base hides only the base's
    // own picture; its attach rows stay independent).
    if (!layer.isVisible || layer.opacity <= 0) {
      continue;
    }
    // Folder gates (L3): a hidden ancestor hides the subtree; folder
    // opacity folds into the member's, folder poses ride the entry.
    final folderChain = resolveFolderChainAt(
      cut: cut,
      layer: layer,
      frameIndex: frameIndex,
    );
    if (!folderChain.visible) {
      continue;
    }
    final fxCarrier = base ?? layer;
    final fxEnabled = !fxBypassedLayerIds.contains(fxCarrier.id);
    final opacity =
        ((fxEnabled
                    ? layer.opacity *
                          resolveOpacityTrackAt(
                            fxCarrier.transformTrack.opacity,
                            frameIndex,
                          )
                    : layer.opacity) *
                folderChain.opacityFactor)
            .clamp(0.0, 1.0)
            .toDouble();
    if (opacity <= 0) {
      continue;
    }

    // SYNCED attach cels resolve through the base's exposure + the cell
    // links; FREE attach rows (UI-R21 #3) expose their OWN timeline like
    // a normal layer — the base still carries eye cascade and FX above.
    final frame = base == null || !isSyncedAttachedLayer(layer)
        ? resolveExposedFrameAt(layer, frameIndex)
        : resolveAttachedFrameAt(
            attached: layer,
            base: base,
            frameIndex: frameIndex,
          );
    if (frame == null) {
      continue;
    }

    final layerPose = fxEnabled
        ? resolveLayerPoseAt(
            layer: fxCarrier,
            canvasSize: cut.canvasSize,
            frameIndex: frameIndex,
          )
        : null;
    final combined = composeFolderAndLayerPose(
      folderPoses: folderChain.poses,
      layerSample: layerPose == null
          ? null
          : (
              pose: layerPose,
              anchorPoint: fxEnabled
                  ? resolveLayerAnchorPointAt(
                      layer: fxCarrier,
                      frameIndex: frameIndex,
                    )
                  : null,
            ),
      canvasSize: cut.canvasSize,
    );
    entries.add(
      CutFrameCompositeEntry(
        layer: layer,
        frame: frame,
        opacity: opacity,
        // The blend is the ROW's own (attach rows keep theirs — their
        // pixels are independent even when timing rides the base); a
        // member that sets none inherits its folder's (R27 #29).
        blendMode: layer.blendMode == LayerBlendMode.normal
            ? folderChain.blendMode
            : layer.blendMode,
        pose: combined?.pose,
        anchorPoint: combined?.anchorPoint,
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
}) {
  final plan = <CutFrameCompositeLayer>[];
  for (final entry in resolveCutFrameCompositeEntries(
    cut: cut,
    frameIndex: frameIndex,
    fxBypassedLayerIds: fxBypassedLayerIds,
  )) {
    final surface = surfaceResolver(entry.layer, entry.frame);
    if (surface == null) {
      continue;
    }
    plan.add(
      CutFrameCompositeLayer(
        surface: surface,
        opacity: entry.opacity,
        blendMode: entry.blendMode,
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
