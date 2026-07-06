import '../../models/layer.dart';
import 'timeline_section_policy.dart';

/// Returns the visual stack order used by the horizontal timeline.
///
/// The raw cut layer list is the logical cel/XSheet order (left-to-right);
/// the horizontal timeline displays a reversed copy so higher layers sit
/// above lower ones, with the timesheet sections enforced (camera rows on
/// top, drawing cels at the bottom) without mutating model order.
List<Layer> horizontalLayerDisplayOrder(List<Layer> layers) {
  return List<Layer>.of(sectionedLayerOrder(layers).reversed);
}

/// Returns the X-sheet column order: the raw/timesheet reading order with
/// the sections enforced (ACTION cel columns on the left, camera on the
/// right, like a paper sheet).
List<Layer> xsheetLayerDisplayOrder(List<Layer> layers) {
  return sectionedLayerOrder(layers);
}
