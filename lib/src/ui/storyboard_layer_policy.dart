import '../models/cut.dart';
import '../models/layer.dart';
import '../models/layer_kind.dart';

Layer? storyboardLayerForCut(Cut cut) {
  Layer? storyboardLayer;

  for (final layer in cut.layers) {
    if (layer.kind != LayerKind.storyboard) {
      continue;
    }

    if (storyboardLayer != null) {
      throw StateError(
        'Cut ${cut.id.value} contains multiple storyboard layers.',
      );
    }

    storyboardLayer = layer;
  }

  return storyboardLayer;
}
