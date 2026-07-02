import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/layer_id.dart';
import '../core/timeline/timeline_defaults.dart';
import 'default_layer_helpers.dart';

const defaultCutCanvasSize = CanvasSize(width: 2340, height: 1654);
const defaultCutDuration = defaultCutDurationFrames;

Cut createDefaultCut({
  required CutId cutId,
  required String name,
  required LayerId layerId,
  CanvasSize canvasSize = defaultCutCanvasSize,
}) {
  return Cut(
    id: cutId,
    name: name,
    layers: [
      createDefaultAnimationLayer(
        layerId: layerId,
        cut: Cut(
          id: cutId,
          name: name,
          layers: const [],
          duration: defaultCutDuration,
          canvasSize: canvasSize,
        ),
      ),
    ],
    duration: defaultCutDuration,
    canvasSize: canvasSize,
  );
}
