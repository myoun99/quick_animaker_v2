import 'dart:collection';

import '../../models/frame.dart';
import '../../models/layer.dart';
import '../../models/layer_kind.dart';
import '../../models/timeline_exposure.dart';
import '../../models/timeline_mark.dart';

class LayerCopyPayload {
  LayerCopyPayload({
    required this.name,
    required this.kind,
    required this.isVisible,
    required this.opacity,
    required List<Frame> frames,
    required Map<int, TimelineExposure> timeline,
    required Map<int, TimelineMark> marks,
  }) : frames = List.unmodifiable(frames),
       timeline = UnmodifiableMapView(
         SplayTreeMap<int, TimelineExposure>.of(timeline),
       ),
       marks = UnmodifiableMapView(SplayTreeMap<int, TimelineMark>.of(marks));

  final String name;
  final LayerKind kind;
  final bool isVisible;
  final double opacity;
  final List<Frame> frames;
  final Map<int, TimelineExposure> timeline;
  final Map<int, TimelineMark> marks;
}

LayerCopyPayload copyLayerToPayload(Layer source) {
  return LayerCopyPayload(
    name: source.name,
    kind: source.kind,
    isVisible: source.isVisible,
    opacity: source.opacity,
    frames: source.frames,
    timeline: source.timeline,
    marks: source.marks,
  );
}
