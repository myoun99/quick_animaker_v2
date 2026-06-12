import '../../models/layer.dart';

/// Returns the visual stack order used by the horizontal timeline.
///
/// The raw cut layer list is the logical cel/XSheet order (left-to-right),
/// so the horizontal timeline displays a defensive reversed copy to show
/// higher layers above lower layers without mutating model order.
List<Layer> horizontalLayerDisplayOrder(List<Layer> layers) {
  return List<Layer>.of(layers.reversed);
}
