import 'cut_id.dart';
import 'layer.dart';
import 'layer_id.dart';
import 'layer_kind.dart';

/// Fixture layers every cut carries alongside the camera: the timesheet's
/// two SE columns (S1·S2) and one camera-work instruction row (CAM 1).
/// New cuts create them; [withEnsuredSectionLayers] backfills older files
/// on load. Deletion floors (SE ≥ 2, instruction ≥ 1) live in the session
/// and command guards.

LayerId seLayerIdForCut(CutId cutId, int slot) =>
    LayerId('${cutId.value}-se-$slot');

LayerId instructionLayerIdForCut(CutId cutId) =>
    LayerId('${cutId.value}-instructions');

Layer createSeLayer({required CutId cutId, required int slot}) {
  return Layer(
    id: seLayerIdForCut(cutId, slot),
    name: 'S$slot',
    frames: const [],
    timeline: const {},
    kind: LayerKind.se,
  );
}

Layer createInstructionLayer({required CutId cutId, String name = 'CAM 1'}) {
  return Layer(
    id: instructionLayerIdForCut(cutId),
    name: name,
    frames: const [],
    timeline: const {},
    kind: LayerKind.instruction,
  );
}

/// Names an additional instruction row: CAM 2, CAM 3, … skipping names the
/// cut already uses.
String nextInstructionLayerName(List<Layer> layers) {
  final usedNames = layers.map((layer) => layer.name).toSet();
  var index = 1;
  while (true) {
    final name = 'CAM $index';
    if (!usedNames.contains(name)) {
      return name;
    }
    index += 1;
  }
}

/// Names an additional SE row: S1, S2, S3, … skipping names the cut
/// already uses (S1 selected + Add Layer → S3 when S1·S2 exist).
String nextSeLayerName(List<Layer> layers) {
  final usedNames = layers.map((layer) => layer.name).toSet();
  var index = 1;
  while (true) {
    final name = 'S$index';
    if (!usedNames.contains(name)) {
      return name;
    }
    index += 1;
  }
}

/// Backfills the SE/instruction fixtures a cut is expected to carry: at
/// least two SE rows and one instruction row. Existing layers are never
/// touched; missing fixtures are inserted before the camera layer (display
/// order is section-sorted anyway). Idempotent — a cut that already meets
/// the floors comes back unchanged (same list instance).
List<Layer> withEnsuredSectionLayers(CutId cutId, List<Layer> layers) {
  final seCount = layers.where((layer) => layer.kind == LayerKind.se).length;
  final hasInstruction = layers.any(
    (layer) => layer.kind == LayerKind.instruction,
  );
  if (seCount >= 2 && hasInstruction) {
    return layers;
  }

  final usedIds = layers.map((layer) => layer.id).toSet();
  final additions = <Layer>[];

  var slot = 1;
  for (var missing = 2 - seCount; missing > 0; missing -= 1) {
    while (usedIds.contains(seLayerIdForCut(cutId, slot))) {
      slot += 1;
    }
    additions.add(createSeLayer(cutId: cutId, slot: slot));
    usedIds.add(seLayerIdForCut(cutId, slot));
  }

  if (!hasInstruction) {
    var id = instructionLayerIdForCut(cutId);
    var suffix = 2;
    while (usedIds.contains(id)) {
      id = LayerId('${instructionLayerIdForCut(cutId).value}-$suffix');
      suffix += 1;
    }
    additions.add(
      createInstructionLayer(
        cutId: cutId,
        name: nextInstructionLayerName(layers),
      ).copyWith(id: id),
    );
  }

  final cameraIndex = layers.indexWhere(
    (layer) => layer.kind == LayerKind.camera,
  );
  final result = List<Layer>.of(layers);
  result.insertAll(cameraIndex < 0 ? result.length : cameraIndex, additions);
  return result;
}
