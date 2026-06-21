import '../models/brush_input_sample.dart';
import '../models/stroke_point.dart';

List<StrokePoint> brushInputSamplesToStrokePoints(
  Iterable<BrushInputSample> samples,
) {
  return List<StrokePoint>.unmodifiable(
    samples.map((sample) => StrokePoint(x: sample.x, y: sample.y)),
  );
}
