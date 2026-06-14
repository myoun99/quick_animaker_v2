import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/layer_kind.dart';
import '../models/stroke.dart';
import '../models/timeline_exposure.dart';
import '../models/timeline_exposure_type.dart';

Cut duplicateCutAsIndependentCopy({
  required Cut source,
  required CutId newCutId,
  required String newName,
  required Map<LayerId, LayerId> layerIdMap,
  required Map<FrameId, FrameId> frameIdMap,
}) {
  return Cut(
    id: newCutId,
    name: newName,
    layers: source.layers
        .map(
          (layer) => _duplicateLayer(
            layer: layer,
            layerIdMap: layerIdMap,
            frameIdMap: frameIdMap,
          ),
        )
        .toList(),
    duration: source.duration,
    canvasSize: source.canvasSize,
    metadata: source.metadata,
  );
}

Layer _duplicateLayer({
  required Layer layer,
  required Map<LayerId, LayerId> layerIdMap,
  required Map<FrameId, FrameId> frameIdMap,
}) {
  final newLayerId = layerIdMap[layer.id];
  if (newLayerId == null) {
    throw ArgumentError.value(
      layerIdMap,
      'layerIdMap',
      'Missing mapped LayerId for source layer ${layer.id}.',
    );
  }

  return duplicateLayerAsIndependentCopy(
    source: layer,
    newLayerId: newLayerId,
    newName: layer.name,
    frameIdMap: frameIdMap,
  );
}

Layer duplicateLayerAsIndependentCopy({
  required Layer source,
  required LayerId newLayerId,
  required String newName,
  required Map<FrameId, FrameId> frameIdMap,
  LayerKind? kind,
}) {
  return Layer(
    id: newLayerId,
    name: newName,
    frames: source.frames
        .map((frame) => _duplicateFrame(frame: frame, frameIdMap: frameIdMap))
        .toList(),
    timeline: source.timeline.map(
      (index, exposure) => MapEntry(
        index,
        _duplicateTimelineExposure(exposure: exposure, frameIdMap: frameIdMap),
      ),
    ),
    marks: source.marks.map((index, mark) => MapEntry(index, mark.copyWith())),
    isVisible: source.isVisible,
    opacity: source.opacity,
    kind: kind ?? source.kind,
  );
}

Frame _duplicateFrame({
  required Frame frame,
  required Map<FrameId, FrameId> frameIdMap,
}) {
  final newFrameId = frameIdMap[frame.id];
  if (newFrameId == null) {
    throw ArgumentError.value(
      frameIdMap,
      'frameIdMap',
      'Missing mapped FrameId for source frame ${frame.id}.',
    );
  }

  return Frame(
    id: newFrameId,
    duration: frame.duration,
    strokes: frame.strokes.map(_duplicateStroke).toList(),
    name: frame.name,
    storyboardMetadata: frame.storyboardMetadata,
  );
}

TimelineExposure _duplicateTimelineExposure({
  required TimelineExposure exposure,
  required Map<FrameId, FrameId> frameIdMap,
}) {
  switch (exposure.type) {
    case TimelineExposureType.blank:
      return const TimelineExposure.blank();
    case TimelineExposureType.drawing:
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
      return TimelineExposure.drawing(newFrameId);
  }
}

Stroke _duplicateStroke(Stroke stroke) {
  return stroke.copyWith(
    points: stroke.points.map((point) => point.copyWith()).toList(),
    brushSettings: stroke.brushSettings.copyWith(),
  );
}
