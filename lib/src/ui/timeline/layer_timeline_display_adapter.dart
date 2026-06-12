import '../../models/layer.dart';

/// Returns the layer order used by the horizontal timeline.
///
/// This adapter intentionally preserves the current incoming order for now,
/// while keeping the timeline UI decoupled from the raw model list so future
/// phases can map layers into horizontal sections without changing callers.
List<Layer> horizontalLayerDisplayOrder(List<Layer> layers) {
  return List<Layer>.of(layers);
}
