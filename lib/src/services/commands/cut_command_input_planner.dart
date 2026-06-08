import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../models/project.dart';

class CreateCutCommandInputPlan {
  const CreateCutCommandInputPlan({
    required this.cutId,
    required this.layerId,
  });

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
    layerId: LayerId(
      _firstAvailableId(prefix: 'layer', usedIds: ids.layerIds),
    ),
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

  final newCutId = CutId(
    _firstAvailableId(prefix: 'cut', usedIds: ids.cutIds),
  );
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
