/// Pure resolution for ATTACH LAYERS (W5): an attach layer has no timeline
/// of its own — at any frame it shows the cel its [Layer.baseFrameLinks]
/// maps from the BASE layer's exposed cel. Cell-level links mean linked-cel
/// reuse on the base re-uses the attached cel too, and comma drags follow
/// for free.
library;

import 'dart:collection';

import 'attached_mode.dart';
import 'attached_placement.dart';
import 'cut.dart';
import 'frame.dart';
import 'frame_id.dart';
import 'layer.dart';
import 'layer_id.dart';
import 'layer_kind.dart';
import 'timeline_coverage.dart';
import 'timeline_exposure.dart';

/// Whether [layer] is an attach layer of EITHER mode (rides a base
/// layer's transform/FX and group structure).
bool isAttachedLayer(Layer layer) => layer.attachedToLayerId != null;

/// Whether [layer] is a SYNCED attach row (UI-R21 #3): its cels ride the
/// base's timeline through the cell links and the row mirrors as ghosts.
/// The TIMING standdowns apply to this mode only — a FREE attach row
/// authors its own timeline like any drawing layer.
bool isSyncedAttachedLayer(Layer layer) =>
    isAttachedLayer(layer) && layer.attachedMode == AttachedMode.synced;

/// Whether [layer] can carry attach layers (v1: drawing kinds only, no
/// nesting — an attach layer is never itself a base).
bool canCarryAttachedLayers(Layer layer) =>
    !isAttachedLayer(layer) &&
    switch (layer.kind) {
      LayerKind.animation || LayerKind.storyboard || LayerKind.art => true,
      LayerKind.camera || LayerKind.se || LayerKind.instruction => false,
    };

/// The base layer [attached] rides, looked up in [layers]; null when the
/// link dangles (base deleted out from under it — display/composite skip
/// such rows).
Layer? attachedBaseOf(Layer attached, List<Layer> layers) {
  final baseId = attached.attachedToLayerId;
  if (baseId == null) {
    return null;
  }
  for (final layer in layers) {
    if (layer.id == baseId) {
      return layer;
    }
  }
  return null;
}

/// The attach layers riding [baseId], in [layers] list order (the list
/// keeps them adjacent to the base: [below…, base, above…]).
List<Layer> attachedLayersOf(LayerId baseId, List<Layer> layers) {
  return [
    for (final layer in layers)
      if (layer.attachedToLayerId == baseId) layer,
  ];
}

/// The attach layer's cel id at [frameIndex]: the base's exposed cel picks
/// the linked cel; null when the base shows nothing there or the base cel
/// has no link on this layer.
FrameId? attachedFrameIdAt({
  required Layer attached,
  required Layer base,
  required int frameIndex,
}) {
  final baseFrameId = exposedFrameIdAt(base.timeline, frameIndex);
  if (baseFrameId == null) {
    return null;
  }
  return attached.baseFrameLinks[baseFrameId];
}

/// The attach layer's cel at [frameIndex] (see [attachedFrameIdAt]); null
/// when unlinked or the linked cel no longer exists.
Frame? resolveAttachedFrameAt({
  required Layer attached,
  required Layer base,
  required int frameIndex,
}) {
  final frameId = attachedFrameIdAt(
    attached: attached,
    base: base,
    frameIndex: frameIndex,
  );
  if (frameId == null) {
    return null;
  }
  for (final frame in attached.frames) {
    if (frame.id == frameId) {
      return frame;
    }
  }
  return null;
}

/// The attach layer's DERIVED timeline: the base's drawing blocks with each
/// linked base cel replaced by the linked attach cel (unlinked blocks and
/// orphan links show as empty cells). Read-only display material — the
/// attach layer's stored timeline stays empty.
///
/// Every entry is a GHOST exposure (UI-R20 #8): the row reads as a mirror
/// of the base — text-only cells, no block chrome, and the timing
/// affordances stand down like on any derived exposure. Drawing and
/// playback still treat ghosts as ordinary exposures, so the attach cels
/// keep editing and compositing through them.
///
/// The base's OWN ghost entries (repeat/hold run-edge instances) mirror
/// with their [TimelineExposure.ghostOwnerId] intact (UI-R24 #2): paired
/// with the base's runBehaviors on the display clone, the mirror row
/// prints the base's hold dashes / repeat notation exactly.
SplayTreeMap<int, TimelineExposure> attachedDisplayTimeline({
  required Layer attached,
  required Layer base,
}) {
  final timeline = SplayTreeMap<int, TimelineExposure>();
  final ownFrameIds = {for (final frame in attached.frames) frame.id};
  for (final entry in base.timeline.entries) {
    final baseFrameId = entry.value.frameId;
    final length = entry.value.length;
    if (!entry.value.isDrawing || baseFrameId == null || length == null) {
      continue;
    }
    final linked = attached.baseFrameLinks[baseFrameId];
    if (linked == null || !ownFrameIds.contains(linked)) {
      continue;
    }
    timeline[entry.key] = TimelineExposure.drawing(
      linked,
      length: length,
      ghost: true,
      ghostOwnerId: entry.value.ghostOwnerId,
    );
  }
  return timeline;
}

/// The attach layer as a cut-local DISPLAY clone whose timeline mirrors the
/// base through the cell links — the same read-via-display-clone pattern
/// the track SE rows use: every read path (rows, selection, brush frame
/// resolution) sees the derived exposures, while writes address the REAL
/// layer through commands.
///
/// The clone carries the BASE's runBehaviors (UI-R24 #2): the mirrored
/// ghost entries keep their owner ids, so the cells painter resolves the
/// base's hold/repeat modes on the mirror row and prints the same dashes.
Layer attachedDisplayLayer({required Layer attached, required Layer base}) {
  return attached.copyWith(
    timeline: attachedDisplayTimeline(attached: attached, base: base),
    runBehaviors: base.runBehaviors,
  );
}

/// The mirror cel id a SYNCED attach row uses for [baseFrameId] (UI-R23 #7
/// v2, auto-mirroring). DETERMINISTIC — reconciliation after an undo/redo
/// or a re-executed command re-mints the identical id, so links, brush
/// frame keys and history replay all stay stable.
FrameId attachedMirrorCelId(LayerId attachedId, FrameId baseFrameId) =>
    FrameId('attach-mirror-${attachedId.value}-${baseFrameId.value}');

/// [cut] with every SYNCED attach row's mirror COMPLETED (UI-R23 #7 v2,
/// the always-mirror invariant): one own cel + cell link per base cel, so
/// the row mirrors the base's whole timeline in real time no matter how
/// the base gained the cel (create, cross-row move, paste, redo, load).
///
/// Runs on every repository write as a NORMALIZATION — pure adds only:
/// missing links gain a fresh empty cel; links whose cel object is missing
/// (while their base cel lives) get the cel re-materialized under the SAME
/// id; orphan links (base cel deleted) stay untouched by design
/// (audio-clip semantics — the cel comes back with the base cel).
/// Identity-preserving: an already-complete cut returns the SAME instance
/// (no-op writes stay no-ops for dirty tracking).
Cut cutWithReconciledAttachedMirrors(Cut cut) {
  List<Layer>? nextLayers;
  for (var i = 0; i < cut.layers.length; i += 1) {
    final layer = cut.layers[i];
    if (!isSyncedAttachedLayer(layer)) {
      continue;
    }
    final base = attachedBaseOf(layer, cut.layers);
    if (base == null) {
      continue; // Dangling link — display skips the row; nothing to add.
    }
    final ownFrameIds = {for (final frame in layer.frames) frame.id};
    List<Frame>? addedFrames;
    Map<FrameId, FrameId>? addedLinks;
    for (final entry in base.timeline.entries) {
      final baseFrameId = entry.value.frameId;
      if (!entry.value.isDrawing || entry.value.ghost || baseFrameId == null) {
        continue;
      }
      final linked =
          layer.baseFrameLinks[baseFrameId] ?? addedLinks?[baseFrameId];
      if (linked != null) {
        // Link present — re-materialize the cel if its object went missing.
        if (!ownFrameIds.contains(linked)) {
          (addedFrames ??= []).add(
            Frame(id: linked, duration: 1, strokes: const []),
          );
          ownFrameIds.add(linked);
        }
        continue;
      }
      final celId = attachedMirrorCelId(layer.id, baseFrameId);
      (addedFrames ??= []).add(
        Frame(id: celId, duration: 1, strokes: const []),
      );
      ownFrameIds.add(celId);
      (addedLinks ??= {})[baseFrameId] = celId;
    }
    if (addedFrames == null && addedLinks == null) {
      continue;
    }
    nextLayers ??= [...cut.layers];
    nextLayers[i] = layer.copyWith(
      frames: [...layer.frames, ...?addedFrames],
      baseFrameLinks: addedLinks == null
          ? null
          : {...layer.baseFrameLinks, ...addedLinks},
    );
  }
  return nextLayers == null ? cut : cut.copyWith(layers: nextLayers);
}

/// The index just past [baseId]'s attach group — base plus its contiguous
/// attach rows — in [layers]; insertion point for "add above the group".
int attachedGroupEndIndex(LayerId baseId, List<Layer> layers) {
  var end = layers.indexWhere((layer) => layer.id == baseId);
  if (end == -1) {
    return layers.length;
  }
  end += 1;
  while (end < layers.length && layers[end].attachedToLayerId == baseId) {
    end += 1;
  }
  return end;
}

/// A fresh attach-row name, signed by placement (UI-R20 #11, the
/// mathematical read): rows stacking ABOVE the base are `+1`, `+2`, …,
/// rows below are `-1`, `-2`, … — each side numbers its own count.
///
/// R26 #29: the sign hangs off the BASE's name, no space — a row attached
/// above layer `B` is `B+1`, below is `B-1`.
String nextAttachedLayerName(
  Layer base,
  List<Layer> layers,
  AttachedPlacement placement,
) {
  var existing = 0;
  for (final layer in attachedLayersOf(base.id, layers)) {
    if (layer.attachedPlacement == placement) {
      existing += 1;
    }
  }
  final sign = placement == AttachedPlacement.above ? '+' : '-';
  return '${base.name}$sign${existing + 1}';
}
