import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';

const defaultCutCanvasSize = CanvasSize(width: 1280, height: 720);

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
      Layer(id: layerId, name: 'Layer 1', frames: const [], timeline: const {}),
    ],
    duration: 1,
    canvasSize: canvasSize,
  );
}
