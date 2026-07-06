import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/frame_id.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../../models/project.dart';
import '../clipboard/layer_copy_payload.dart';

class CreateCutCommandInputPlan {
  const CreateCutCommandInputPlan({required this.cutId, required this.layerId});

  final CutId cutId;
  final LayerId layerId;
}

class DeleteLastCutReplacementInputPlan {
  const DeleteLastCutReplacementInputPlan({
    required this.replacementCutId,
    required this.replacementLayerId,
  });

  final CutId replacementCutId;
  final LayerId replacementLayerId;
}

class PasteLayerCommandInputPlan {
  PasteLayerCommandInputPlan({
    required this.newLayerId,
    required Map<FrameId, FrameId> frameIdMap,
    required this.layer,
    required this.insertionIndex,
  }) : frameIdMap = Map.unmodifiable(frameIdMap);

  final LayerId newLayerId;
  final Map<FrameId, FrameId> frameIdMap;
  final Layer layer;
  final int insertionIndex;
}

class DuplicateCutCommandInputPlan {
  DuplicateCutCommandInputPlan({
    required this.newCutId,
    required Map<LayerId, LayerId> layerIdMap,
    required Map<FrameId, FrameId> frameIdMap,
  }) : layerIdMap = Map.unmodifiable(layerIdMap),
       frameIdMap = Map.unmodifiable(frameIdMap);

  final CutId newCutId;
  final Map<LayerId, LayerId> layerIdMap;
  final Map<FrameId, FrameId> frameIdMap;
}

CreateCutCommandInputPlan planCreateCutCommandInput(Project project) {
  final ids = _ProjectIdSnapshot.fromProject(project);
  return CreateCutCommandInputPlan(
    cutId: CutId(_firstAvailableId(prefix: 'cut', usedIds: ids.cutIds)),
    layerId: LayerId(_firstAvailableId(prefix: 'layer', usedIds: ids.layerIds)),
  );
}

DeleteLastCutReplacementInputPlan planDeleteLastCutReplacementInput(
  Project project,
) {
  final ids = _ProjectIdSnapshot.fromProject(project);
  return DeleteLastCutReplacementInputPlan(
    replacementCutId: CutId(
      _firstAvailableId(prefix: 'cut', usedIds: ids.cutIds),
    ),
    replacementLayerId: LayerId(
      _firstAvailableId(prefix: 'layer', usedIds: ids.layerIds),
    ),
  );
}

DuplicateCutCommandInputPlan planDuplicateCutCommandInput({
  required Project project,
  required Cut sourceCut,
}) {
  final ids = _ProjectIdSnapshot.fromProject(project);
  ids.includeCut(sourceCut);

  final newCutId = CutId(_firstAvailableId(prefix: 'cut', usedIds: ids.cutIds));
  ids.cutIds.add(newCutId.value);

  final layerIdMap = <LayerId, LayerId>{};
  final frameIdMap = <FrameId, FrameId>{};

  for (final layer in sourceCut.layers) {
    final newLayerId = LayerId(
      _firstAvailableId(prefix: 'layer', usedIds: ids.layerIds),
    );
    ids.layerIds.add(newLayerId.value);
    layerIdMap[layer.id] = newLayerId;

    for (final frame in layer.frames) {
      if (frameIdMap.containsKey(frame.id)) {
        continue;
      }
      final newFrameId = FrameId(
        _firstAvailableId(prefix: 'frame', usedIds: ids.frameIds),
      );
      ids.frameIds.add(newFrameId.value);
      frameIdMap[frame.id] = newFrameId;
    }

    for (final exposure in layer.timeline.values) {
      final frameId = exposure.frameId;
      if (frameId == null || frameIdMap.containsKey(frameId)) {
        continue;
      }
      final newFrameId = FrameId(
        _firstAvailableId(prefix: 'frame', usedIds: ids.frameIds),
      );
      ids.frameIds.add(newFrameId.value);
      frameIdMap[frameId] = newFrameId;
    }
  }

  return DuplicateCutCommandInputPlan(
    newCutId: newCutId,
    layerIdMap: layerIdMap,
    frameIdMap: frameIdMap,
  );
}

PasteLayerCommandInputPlan planPasteLayerCommandInput({
  required Project project,
  required Cut targetCut,
  required LayerCopyPayload payload,
  required int insertionIndex,
}) {
  final ids = _ProjectIdSnapshot.fromProject(project)..includeCut(targetCut);
  final newLayerId = LayerId(
    _firstAvailableId(prefix: 'layer', usedIds: ids.layerIds),
  );
  ids.layerIds.add(newLayerId.value);

  final frameIdMap = <FrameId, FrameId>{};
  for (final frame in payload.frames) {
    frameIdMap.putIfAbsent(frame.id, () {
      final id = FrameId(
        _firstAvailableId(prefix: 'frame', usedIds: ids.frameIds),
      );
      ids.frameIds.add(id.value);
      return id;
    });
  }
  for (final exposure in payload.timeline.values) {
    final frameId = exposure.frameId;
    if (frameId == null) continue;
    frameIdMap.putIfAbsent(frameId, () {
      final id = FrameId(
        _firstAvailableId(prefix: 'frame', usedIds: ids.frameIds),
      );
      ids.frameIds.add(id.value);
      return id;
    });
  }

  final hasStoryboardLayer = targetCut.layers.any(
    (layer) => layer.kind == LayerKind.storyboard,
  );
  final pastedKind = payload.kind == LayerKind.storyboard && !hasStoryboardLayer
      ? LayerKind.storyboard
      : LayerKind.animation;
  final layer = Layer(
    id: newLayerId,
    name: payload.name,
    frames: payload.frames
        .map((frame) => frame.copyWith(id: frameIdMap[frame.id]))
        .toList(),
    timeline: payload.timeline.map((index, exposure) {
      if (exposure.isMark) {
        return MapEntry(index, exposure);
      }
      final sourceFrameId = exposure.frameId;
      final newFrameId = sourceFrameId == null
          ? null
          : frameIdMap[sourceFrameId];
      if (sourceFrameId == null || newFrameId == null) {
        throw ArgumentError.value(
          frameIdMap,
          'frameIdMap',
          'Missing mapped FrameId for timeline exposure ${exposure.frameId}.',
        );
      }
      return MapEntry(index, exposure.copyWith(frameId: newFrameId));
    }),
    isVisible: payload.isVisible,
    opacity: payload.opacity,
    kind: pastedKind,
  );

  return PasteLayerCommandInputPlan(
    newLayerId: newLayerId,
    frameIdMap: frameIdMap,
    layer: layer,
    insertionIndex: insertionIndex,
  );
}

String _firstAvailableId({
  required String prefix,
  required Set<String> usedIds,
}) {
  var candidateNumber = 1;
  while (true) {
    final candidate = '$prefix-$candidateNumber';
    if (!usedIds.contains(candidate)) {
      return candidate;
    }
    candidateNumber += 1;
  }
}

class _ProjectIdSnapshot {
  _ProjectIdSnapshot({
    required this.cutIds,
    required this.layerIds,
    required this.frameIds,
  });

  factory _ProjectIdSnapshot.fromProject(Project project) {
    final snapshot = _ProjectIdSnapshot(
      cutIds: <String>{},
      layerIds: <String>{},
      frameIds: <String>{},
    );

    for (final track in project.tracks) {
      for (final cut in track.cuts) {
        snapshot.includeCut(cut);
      }
    }

    return snapshot;
  }

  final Set<String> cutIds;
  final Set<String> layerIds;
  final Set<String> frameIds;

  void includeCut(Cut cut) {
    cutIds.add(cut.id.value);
    for (final layer in cut.layers) {
      layerIds.add(layer.id.value);
      for (final frame in layer.frames) {
        frameIds.add(frame.id.value);
      }
      for (final exposure in layer.timeline.values) {
        final frameId = exposure.frameId;
        if (frameId != null) {
          frameIds.add(frameId.value);
        }
      }
    }
  }
}
