import '../models/cut.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/timeline_exposure.dart';

String celLayerNameForIndex(int index) {
  if (index < 0) {
    throw ArgumentError.value(
      index,
      'index',
      'Cel layer name index must be non-negative.',
    );
  }

  var value = index;
  var name = '';
  do {
    final letter = String.fromCharCode('A'.codeUnitAt(0) + (value % 26));
    name = letter + name;
    value = (value ~/ 26) - 1;
  } while (value >= 0);

  return name;
}

String nextCelLayerNameForCut(Cut cut) {
  final usedNames = cut.layers.map((layer) => layer.name).toSet();
  var index = 0;
  while (true) {
    final name = celLayerNameForIndex(index);
    if (!usedNames.contains(name)) {
      return name;
    }
    index += 1;
  }
}

Layer createDefaultAnimationLayer({
  required LayerId layerId,
  required Cut cut,
}) {
  return Layer(
    id: layerId,
    name: nextCelLayerNameForCut(cut),
    frames: const [],
    timeline: const {0: TimelineExposure.blank()},
  );
}
